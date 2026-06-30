#!/usr/bin/env bash
#
# extract.sh: command dispatcher for tmux-extract-revamped.
#
# Usage: extract.sh MODE TARGET_PANE [ACTION]
#
# Captures source text, extracts candidates for MODE, shows them in fzf, and acts
# on the choice. MODE is any extractor (all, urls, paths, words, lines, shas,
# ipv4, ipv6, color, uuid, numbers, quoted, bracketed, custom). ACTION is insert
# (default), navigate, open, copy, chooser, or doctor. Everything that touches a
# pane, fzf, the clipboard, or a browser is a seam the tests replace, so the
# suite never runs real fzf, opens a browser, or writes to the clipboard.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/has-command.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/extract/extract.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/extract/dispatch.sh"

# ----------------------------------------------------------------------------
# Seams. Tests override these so nothing interactive or destructive ever runs.
# ----------------------------------------------------------------------------

# _capture_pane TARGET -> the visible pane plus configured scrollback.
_capture_pane() {
  tmux capture-pane -t "${1}" -p -S "-$(get_tmux_option "@extract_revamped_lines" "200")" 2>/dev/null
}

# _capture_all_panes -> every pane in the current window, concatenated, so a
# value sitting in a neighbour pane is reachable from one picker.
_capture_all_panes() {
  local p
  tmux list-panes -F '#{pane_id}' 2>/dev/null | while IFS= read -r p; do
    tmux capture-pane -t "${p}" -p -S "-$(get_tmux_option "@extract_revamped_lines" "200")" 2>/dev/null
  done
}

# _capture_last_log -> the newest file written by tmux-logging-revamped, so the
# picker can mine the last saved capture (cross-plugin source).
_capture_last_log() {
  local dir name
  dir="$(get_tmux_option "@logging_revamped_path" "${HOME}/.tmux/logging-revamped")"
  name="$(ls -1t "${dir}" 2>/dev/null | head -1)"
  [[ -n "${name}" ]] && cat "${dir}/${name}" 2>/dev/null
  return 0
}

# _fzf [ARGS...] -> the fzf picker. Args let callers add --multi or --expect.
# Guarded so a host without fzf degrades to a no-op instead of an error.
_fzf() { command -v fzf >/dev/null 2>&1 && fzf "$@"; return 0; }

# _insert TARGET TEXT -> paste TEXT at the pane's cursor.
_insert() { tmux send-keys -t "${1}" -- "${2}"; }

# _navigate TARGET PATTERN -> open copy-mode and search backward for PATTERN.
_navigate() {
  tmux copy-mode -t "${1}" 2>/dev/null
  tmux send-keys -t "${1}" -X search-backward "${2}" 2>/dev/null
}

# _open_url URL -> hand URL to the desktop browser. One physical line so the
# untestable branch costs a single line of coverage.
_open_url() { if command -v xdg-open >/dev/null 2>&1; then xdg-open "${1}" >/dev/null 2>&1; elif command -v open >/dev/null 2>&1; then open "${1}" >/dev/null 2>&1; fi; return 0; }

# _open_path TARGET PATH -> open PATH in $EDITOR in a new tmux window.
_open_path() { tmux new-window "${EDITOR:-vi} ${2}" 2>/dev/null; return 0; }

# _clip_copy TEXT -> copy TEXT to the system clipboard. One physical line so the
# untestable tool selection costs a single line of coverage.
_clip_copy() { if command -v pbcopy >/dev/null 2>&1; then printf '%s' "${1}" | pbcopy; elif command -v wl-copy >/dev/null 2>&1; then printf '%s' "${1}" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf '%s' "${1}" | xclip -selection clipboard; fi; return 0; }

# _emit_osc52 SEQUENCE -> write an OSC 52 escape to the terminal. The escape
# reaches the outer terminal through the popup, so SSH clipboards work too.
_emit_osc52() { printf '%s' "${1}"; }

# _b64 TEXT -> base64 of TEXT with newlines stripped, for the OSC 52 payload.
_b64() { printf '%s' "${1}" | base64 | tr -d '\n'; }

# ----------------------------------------------------------------------------
# Candidate building.
# ----------------------------------------------------------------------------

# _extract_for MODE TEXT -> the raw candidate list for MODE.
_extract_for() {
  case "${1}" in
    urls) extract_urls "${2}" ;;
    paths) extract_paths "${2}" ;;
    words) extract_words "${2}" ;;
    lines) extract_lines "${2}" ;;
    shas) extract_shas "${2}" ;;
    ipv4) extract_ipv4 "${2}" ;;
    ipv6) extract_ipv6 "${2}" ;;
    color | colors | hex) extract_hex_colors "${2}" ;;
    uuid | uuids) extract_uuids "${2}" ;;
    numbers | nums) extract_numbers "${2}" ;;
    quoted) extract_quoted "${2}" ;;
    bracketed) extract_bracketed "${2}" ;;
    custom) extract_custom "$(get_tmux_option "@extract_revamped_custom_regex" "")" "${2}" ;;
    *) extract_all "${2}" ;;
  esac
}

# _candidates MODE TEXT -> the extractor output after min-length, reverse, and
# frecency tuning, each gated by its own option.
_candidates() {
  local mode="${1}" text="${2}" items minlen reverse frec recent
  items="$(_extract_for "${mode}" "${text}")"
  minlen="$(get_tmux_option "@extract_revamped_min_length" "0")"
  items="$(extract_min_length "${minlen}" "${items}")"
  reverse="$(get_tmux_option "@extract_revamped_reverse" "0")"
  if [[ "${reverse}" == "1" ]]; then
    items="$(extract_reverse "${items}")"
  fi
  frec="$(get_tmux_option "@extract_revamped_frecency" "0")"
  if [[ "${frec}" == "1" ]]; then
    recent="$(get_tmux_option "@extract_revamped_recent" "")"
    items="$(frecency_reorder "${recent}" "${items}")"
  fi
  printf '%s' "${items}"
}

# _gather_text TARGET -> source text for the configured scope.
_gather_text() {
  local target="${1}" scope
  scope="$(get_tmux_option "@extract_revamped_scope" "pane")"
  case "${scope}" in
    all-panes) _capture_all_panes ;;
    last-log) _capture_last_log ;;
    *) _capture_pane "${target}" ;;
  esac
}

# _fzf_select -> run the picker, honouring multi-select.
_fzf_select() {
  if [[ "$(get_tmux_option "@extract_revamped_multi" "0")" == "1" ]]; then
    _fzf --no-sort --reverse --height=100% --multi
  else
    _fzf --no-sort --reverse --height=100%
  fi
}

# ----------------------------------------------------------------------------
# Actions.
# ----------------------------------------------------------------------------

# _open_selection TARGET SEL -> open the first value by type, paste it otherwise.
_open_selection() {
  local target="${1}" first kind
  first="$(first_line "${2}")"
  kind="$(classify_target "${first}")"
  case "${kind}" in
    url) _open_url "${first}" ;;
    path) _open_path "${target}" "${first}" ;;
    *) _insert "${target}" "${first}" ;;
  esac
  return 0
}

# _copy_selection SEL -> copy via OSC 52 when enabled, else the local clipboard.
_copy_selection() {
  if [[ "$(get_tmux_option "@extract_revamped_osc52" "0")" == "1" ]]; then
    _emit_osc52 "$(osc52_sequence "$(_b64 "${1}")")"
  else
    _clip_copy "${1}"
  fi
  return 0
}

# _record_if_enabled SEL -> remember the pick for frecency, capped at 20 entries.
_record_if_enabled() {
  local recent new
  [[ "$(get_tmux_option "@extract_revamped_frecency" "0")" == "1" ]] || return 0
  recent="$(get_tmux_option "@extract_revamped_recent" "")"
  new="$(printf '%s\n%s\n' "$(first_line "${1}")" "${recent}" | awk 'NF && !seen[$0]++' | awk 'NR<=20')"
  set_tmux_option "@extract_revamped_recent" "${new}"
  return 0
}

# run_doctor -> print a capability report of the optional tools on this host.
run_doctor() {
  local fzf opener clip b64
  if has_command fzf; then fzf=yes; else fzf=no; fi
  if has_command xdg-open || has_command open; then opener=yes; else opener=no; fi
  if has_command pbcopy || has_command wl-copy || has_command xclip; then clip=yes; else clip=no; fi
  if has_command base64; then b64=yes; else b64=no; fi
  doctor_report "${fzf}" "${opener}" "${clip}" "${b64}"
}

# _run_interactive MODE TARGET TEXT -> a bounded picker loop where ctrl-n cycles
# the extractor, ctrl-o opens, ctrl-y copies, and Enter inserts the choice.
_run_interactive() {
  local mode="${1}" target="${2}" text="${3}" cycle_list out key sel items guard=0
  cycle_list="$(get_tmux_option "@extract_revamped_modes" "all urls paths words lines")"
  while ((guard < 12)); do
    guard=$((guard + 1))
    items="$(_candidates "${mode}" "${text}")"
    [[ -z "${items}" ]] && return 0
    out="$(printf '%s\n' "${items}" | _fzf --no-sort --reverse --height=100% --multi --expect=ctrl-o,ctrl-y,ctrl-n)"
    [[ -z "${out}" ]] && return 0
    key="$(parse_expect_key "${out}")"
    sel="$(parse_expect_rest "${out}")"
    [[ -z "${sel}" ]] && return 0
    case "${key}" in
      ctrl-n) mode="$(next_mode "${mode}" "${cycle_list}")" ;;
      ctrl-o) _record_if_enabled "${sel}"; _open_selection "${target}" "${sel}"; return 0 ;;
      ctrl-y) _record_if_enabled "${sel}"; _copy_selection "${sel}"; return 0 ;;
      *) _record_if_enabled "${sel}"; _insert "${target}" "$(join_selection ' ' "${sel}")"; return 0 ;;
    esac
  done
  return 0
}

# extract_run MODE TARGET ACTION -> the top-level flow.
extract_run() {
  local mode="${1:-all}" target="${2:-}" action="${3:-insert}" text items selection
  if [[ "${action}" == "doctor" ]]; then
    run_doctor
    return 0
  fi
  text="$(_gather_text "${target}")"
  if [[ "${action}" == "chooser" ]]; then
    _run_interactive "${mode}" "${target}" "${text}"
    return 0
  fi
  items="$(_candidates "${mode}" "${text}")"
  [[ -z "${items}" ]] && return 0
  selection="$(printf '%s\n' "${items}" | _fzf_select)"
  [[ -z "${selection}" ]] && return 0
  _record_if_enabled "${selection}"
  case "${action}" in
    navigate) _navigate "${target}" "$(extract_regex_escape "$(first_line "${selection}")")" ;;
    open) _open_selection "${target}" "${selection}" ;;
    copy) _copy_selection "${selection}" ;;
    *) _insert "${target}" "$(join_selection ' ' "${selection}")" ;;
  esac
  return 0
}

main() {
  extract_run "${1:-all}" "${2:-}" "${3:-insert}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
