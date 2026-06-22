#!/usr/bin/env bash
#
# extract-revamped.tmux: TPM entry point.
#
# Binds a key that opens an fzf popup over the current pane's captured text. The
# popup runs the dispatcher with the pane id, so the chosen candidate is inserted
# back into the right pane.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_CMD="${CURRENT_DIR}/src/extract.sh"

get_opt() {
  local v
  v=$(tmux show-option -gqv "${1}")
  echo "${v:-${2}}"
}

chmod +x "${EXTRACT_CMD}" 2>/dev/null || true

key="$(get_opt "@extract_revamped_key" "Tab")"
mode="$(get_opt "@extract_revamped_mode" "all")"
width="$(get_opt "@extract_revamped_popup_width" "80%")"
height="$(get_opt "@extract_revamped_popup_height" "60%")"

tmux bind-key "${key}" display-popup -E -w "${width}" -h "${height}" "${EXTRACT_CMD} ${mode} '#{pane_id}'"
