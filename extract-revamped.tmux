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

# Optional action keys. Each is opt-in so the plugin claims only one key by
# default. They reuse the same dispatcher with a different action argument.
bind_action() {
  local opt="${1}" action="${2}" k
  k="$(get_opt "${opt}" "")"
  if [[ -n "${k}" ]]; then
    tmux bind-key "${k}" display-popup -E -w "${width}" -h "${height}" \
      "${EXTRACT_CMD} ${mode} '#{pane_id}' ${action}"
  fi
}

# Jump to the choice in copy-mode instead of pasting it.
bind_action "@extract_revamped_navigate_key" "navigate"
# Open the choice by type: URL to the browser, path to $EDITOR.
bind_action "@extract_revamped_open_key" "open"
# Copy the choice to the clipboard (or over SSH via OSC 52 when enabled).
bind_action "@extract_revamped_copy_key" "copy"
# In-popup chooser: cycle extractor with ctrl-n, ctrl-o opens, ctrl-y copies.
bind_action "@extract_revamped_chooser_key" "chooser"

# Doctor: report which optional tools (fzf, opener, clipboard, base64) exist.
doctor_key="$(get_opt "@extract_revamped_doctor_key" "")"
if [[ -n "${doctor_key}" ]]; then
  tmux bind-key "${doctor_key}" display-popup -E -w "${width}" -h "${height}" \
    "${EXTRACT_CMD} ${mode} '#{pane_id}' doctor; read -r"
fi
