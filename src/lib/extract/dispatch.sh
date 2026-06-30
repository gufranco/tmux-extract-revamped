#!/usr/bin/env bash
#
# dispatch.sh: pure decision helpers for the extract dispatcher.
#
# These are pure: text in, text out, no fzf, no pane, no clipboard, no browser.
# The side-effecting actions (open a URL, copy to the clipboard, run fzf) live in
# the dispatcher behind seams. Keeping the decisions here keeps them testable.

[[ -n "${_EXTRACT_REVAMPED_DISPATCH_LOADED:-}" ]] && return 0
_EXTRACT_REVAMPED_DISPATCH_LOADED=1

# classify_target STR -> "url", "path", or "other". Drives type-aware open:
# URLs go to the browser, paths go to the editor, anything else is pasted.
classify_target() {
  local s="${1}"
  case "${s}" in
    http://* | https://* | ftp://* | file://*) printf 'url'; return 0 ;;
    /* | ~/* | ./* | ../*) printf 'path'; return 0 ;;
  esac
  case "${s}" in
    *@*.*) printf 'url' ;;
    */*) printf 'path' ;;
    *) printf 'other' ;;
  esac
}

# join_selection SEP TEXT -> the non-blank lines of TEXT joined by SEP, so a
# multi-select returns one string the dispatcher can insert in a single paste.
join_selection() {
  local sep="${1}" text="${2}"
  printf '%s\n' "${text}" \
    | awk -v s="${sep}" 'NF{a[++n]=$0} END{for(i=1;i<=n;i++) printf "%s%s",(i>1?s:""),a[i]}'
}

# first_line TEXT -> the first non-blank line, for actions that take one value.
first_line() {
  printf '%s\n' "${1}" | awk 'NF{print; exit}'
}

# next_mode CURRENT LIST -> the mode after CURRENT in the space-separated LIST,
# wrapping past the end and falling back to the first when CURRENT is unknown.
next_mode() {
  local cur="${1}" list="${2}" first="" found=0 m
  for m in ${list}; do
    [[ -z "${first}" ]] && first="${m}"
    if [[ "${found}" == "1" ]]; then
      printf '%s' "${m}"
      return 0
    fi
    [[ "${m}" == "${cur}" ]] && found=1
  done
  printf '%s' "${first}"
  return 0
}

# parse_expect_key OUT -> the first line of fzf --expect output, the pressed key.
parse_expect_key() {
  printf '%s\n' "${1}" | awk 'NR==1{print; exit}'
}

# parse_expect_rest OUT -> every line after the first, the actual selection(s).
parse_expect_rest() {
  printf '%s\n' "${1}" | awk 'NR>1'
}

# osc52_sequence B64 -> the OSC 52 set-clipboard escape carrying an already
# base64-encoded payload. Pure string assembly; the emit is a seam.
osc52_sequence() {
  printf '\033]52;c;%s\a' "${1}"
}

# frecency_reorder RECENT ITEMS -> ITEMS with any line also present in RECENT
# floated to the top in ITEMS order, the rest following, de-duplicated.
frecency_reorder() {
  local recent="${1}" items="${2}"
  {
    printf '%s\n' "${items}" | grep -xF -f <(printf '%s\n' "${recent}" | awk 'NF') 2>/dev/null
    printf '%s\n' "${items}" | grep -vxF -f <(printf '%s\n' "${recent}" | awk 'NF') 2>/dev/null
  } | awk 'NF && !seen[$0]++'
}

# doctor_report FZF OPENER CLIP BASE64 -> a glyph-free capability report so a
# user can see which optional tools this host has before a token comes up empty.
doctor_report() {
  printf 'tmux-extract-revamped doctor\n'
  printf '  fzf picker:    %s\n' "${1}"
  printf '  url opener:    %s\n' "${2}"
  printf '  clipboard:     %s\n' "${3}"
  printf '  base64 (osc52): %s\n' "${4}"
}

export -f classify_target
export -f join_selection
export -f first_line
export -f next_mode
export -f parse_expect_key
export -f parse_expect_rest
export -f osc52_sequence
export -f frecency_reorder
export -f doctor_report
