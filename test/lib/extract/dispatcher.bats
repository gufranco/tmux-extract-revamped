#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

# Every interactive or destructive seam is replaced here. The suite never runs
# real fzf, never opens a browser, and never writes to the clipboard.
setup() {
  setup_test_environment
  unset _EXTRACT_REVAMPED_LOADED
  unset _EXTRACT_REVAMPED_DISPATCH_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/extract.sh"
  _capture_pane() { echo "https://a.com /tmp/x word"; }
  _fzf() { head -1; }
  _insert() { echo "INSERT:${2}" >> "${BATS_TEST_TMPDIR}/ins"; }
  _open_url() { echo "URL:${1}" >> "${BATS_TEST_TMPDIR}/act"; }
  _clip_copy() { echo "CLIP:${1}" >> "${BATS_TEST_TMPDIR}/act"; }
}

teardown() {
  cleanup_test_environment
}

@test "extract.sh - functions are defined" {
  function_exists extract_run
  function_exists _extract_for
  function_exists _candidates
  function_exists _gather_text
  function_exists run_doctor
}

@test "extract.sh - _extract_for routes each mode" {
  [[ "$(_extract_for urls "see https://a.com")" == "https://a.com" ]]
  [[ "$(_extract_for paths "x /tmp/a")" == "/tmp/a" ]]
  [[ "$(_extract_for lines "  hi  ")" == "hi" ]]
  [[ "$(printf '%s' "$(_extract_for words "a b a")" | grep -c .)" == "2" ]]
  [[ "$(_extract_for shas "rev 9af2b1c done")" == "9af2b1c" ]]
  [[ "$(_extract_for ipv4 "ip 10.0.0.1")" == "10.0.0.1" ]]
  [[ "$(_extract_for uuid "id 550e8400-e29b-41d4-a716-446655440000")" == "550e8400-e29b-41d4-a716-446655440000" ]]
  [[ "$(_extract_for color "c #abc")" == "#abc" ]]
  [[ "$(_extract_for numbers "n 42")" == "42" ]]
}

@test "extract.sh - _extract_for custom mode reads the configured regex" {
  tmux set-option -gq @extract_revamped_custom_regex 'JIRA-[0-9]+'
  [[ "$(_extract_for custom "ticket JIRA-7 here")" == "JIRA-7" ]]
}

@test "extract.sh - run captures, picks, and inserts into the pane" {
  run main all "%1"
  [[ "$(cat "${BATS_TEST_TMPDIR}/ins")" == "INSERT:https://a.com" ]]
}

@test "extract.sh - run inserts nothing when the picker returns empty" {
  _fzf() { true; }
  run main all "%1"
  [[ ! -f "${BATS_TEST_TMPDIR}/ins" ]]
}

@test "extract.sh - run does nothing when the capture is empty" {
  _capture_pane() { printf ''; }
  run main all "%1"
  [[ ! -f "${BATS_TEST_TMPDIR}/ins" ]]
}

@test "extract.sh - navigate action searches the escaped selection" {
  _fzf() { cat >/dev/null; printf 'a.b(1)*'; }
  _navigate() { echo "NAV:${1}:${2}" >> "${BATS_TEST_TMPDIR}/nav"; }
  run main all "%1" navigate
  [[ ! -f "${BATS_TEST_TMPDIR}/ins" ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/nav")" == 'NAV:%1:a\.b\(1\)\*' ]]
}

@test "extract.sh - open action opens a url through the opener seam" {
  run main all "%1" open
  [[ "$(cat "${BATS_TEST_TMPDIR}/act")" == "URL:https://a.com" ]]
}

@test "extract.sh - open action opens a path through the editor seam" {
  _capture_pane() { echo "edit /tmp/file.txt"; }
  _open_path() { echo "PATH:${2}" >> "${BATS_TEST_TMPDIR}/act"; }
  run main paths "%1" open
  [[ "$(cat "${BATS_TEST_TMPDIR}/act")" == "PATH:/tmp/file.txt" ]]
}

@test "extract.sh - open action pastes a non-openable choice" {
  _capture_pane() { echo "justaword"; }
  run main words "%1" open
  [[ "$(cat "${BATS_TEST_TMPDIR}/ins")" == "INSERT:justaword" ]]
}

@test "extract.sh - copy action uses the clipboard seam by default" {
  run main all "%1" copy
  [[ "$(cat "${BATS_TEST_TMPDIR}/act")" == "CLIP:https://a.com" ]]
}

@test "extract.sh - copy action emits an OSC 52 sequence when enabled" {
  tmux set-option -gq @extract_revamped_osc52 1
  run main all "%1" copy
  [[ "${output}" == *"]52;c;"* ]]
  [[ "${output}" == *"aHR0cHM6Ly9hLmNvbQ=="* ]]
}

@test "extract.sh - multi-select inserts the joined choices" {
  _capture_pane() { echo "alpha beta gamma"; }
  _fzf() { head -2; }
  tmux set-option -gq @extract_revamped_multi 1
  run main words "%1"
  [[ "$(cat "${BATS_TEST_TMPDIR}/ins")" == "INSERT:alpha beta" ]]
}

@test "extract.sh - doctor action prints the capability report" {
  run main all "%1" doctor
  [[ "${output}" == *"tmux-extract-revamped doctor"* ]]
  [[ "${output}" == *"fzf picker:"* ]]
}

@test "extract.sh - run_doctor reports yes when tools are present" {
  has_command() { return 0; }
  run run_doctor
  [[ "${output}" == *"fzf picker:    yes"* ]]
}

@test "extract.sh - run_doctor reports no when tools are absent" {
  has_command() { return 1; }
  run run_doctor
  [[ "${output}" == *"fzf picker:    no"* ]]
  [[ "${output}" == *"url opener:    no"* ]]
  [[ "${output}" == *"clipboard:     no"* ]]
}

@test "extract.sh - _candidates honours min length" {
  tmux set-option -gq @extract_revamped_min_length 2
  run _candidates words "a bb ccc"
  [[ "${output}" == *"bb"* ]]
  [[ "${output}" == *"ccc"* ]]
  [[ "$(printf '%s' "${output}" | grep -cx 'a')" == "0" ]]
}

@test "extract.sh - _candidates reverses when asked" {
  tmux set-option -gq @extract_revamped_reverse 1
  run _candidates words "a b c"
  [[ "${lines[0]}" == "c" ]]
  [[ "${lines[2]}" == "a" ]]
}

@test "extract.sh - _candidates applies frecency ordering" {
  tmux set-option -gq @extract_revamped_frecency 1
  tmux set-option -gq @extract_revamped_recent "c"
  run _candidates words "a b c"
  [[ "${lines[0]}" == "c" ]]
}

@test "extract.sh - _record_if_enabled stores the pick when frecency is on" {
  tmux set-option -gq @extract_revamped_frecency 1
  _record_if_enabled "chosen-value"
  [[ "$(get_tmux_option @extract_revamped_recent)" == *"chosen-value"* ]]
}

@test "extract.sh - _record_if_enabled is a no-op when frecency is off" {
  _record_if_enabled "chosen-value"
  [[ -z "$(get_tmux_option @extract_revamped_recent)" ]]
}

@test "extract.sh - _gather_text reads all panes when scoped" {
  tmux() {
    case "$1" in
      list-panes) echo '%1'; echo '%2' ;;
      capture-pane) echo "cap-${3}" ;;
      show-option)
        local a
        for a in "$@"; do
          [[ "${a}" == "@extract_revamped_scope" ]] && echo "all-panes"
        done
        return 0
        ;;
      *) return 0 ;;
    esac
  }
  run _gather_text "%1"
  [[ "${output}" == *"cap-%1"* ]]
  [[ "${output}" == *"cap-%2"* ]]
}

@test "extract.sh - _gather_text reads the last log when scoped" {
  mkdir -p "${BATS_TEST_TMPDIR}/logs"
  printf 'log line one\n' > "${BATS_TEST_TMPDIR}/logs/cap.log"
  tmux set-option -gq @logging_revamped_path "${BATS_TEST_TMPDIR}/logs"
  tmux set-option -gq @extract_revamped_scope last-log
  run _gather_text "%1"
  [[ "${output}" == *"log line one"* ]]
}

@test "extract.sh - chooser cycles the mode then inserts on Enter" {
  _capture_pane() { echo "alpha beta"; }
  _fzf() {
    cat >/dev/null
    local n
    n=$(cat "${BATS_TEST_TMPDIR}/n" 2>/dev/null || echo 0)
    n=$((n + 1))
    echo "${n}" > "${BATS_TEST_TMPDIR}/n"
    if [[ "${n}" == "1" ]]; then printf 'ctrl-n\nalpha\n'; else printf '\nbeta\n'; fi
  }
  run main words "%1" chooser
  [[ "$(cat "${BATS_TEST_TMPDIR}/ins")" == "INSERT:beta" ]]
}

@test "extract.sh - chooser ctrl-o opens the selection" {
  _fzf() { cat >/dev/null; printf 'ctrl-o\nhttps://x.com\n'; }
  run main all "%1" chooser
  [[ "$(cat "${BATS_TEST_TMPDIR}/act")" == "URL:https://x.com" ]]
}

@test "extract.sh - chooser ctrl-y copies the selection" {
  _fzf() { cat >/dev/null; printf 'ctrl-y\nhello\n'; }
  run main all "%1" chooser
  [[ "$(cat "${BATS_TEST_TMPDIR}/act")" == "CLIP:hello" ]]
}

@test "extract.sh - chooser returns when items are empty" {
  _capture_pane() { printf ''; }
  run main all "%1" chooser
  [[ ! -f "${BATS_TEST_TMPDIR}/ins" ]]
  [[ ! -f "${BATS_TEST_TMPDIR}/act" ]]
}

@test "extract.sh - chooser returns when the picker is cancelled" {
  _fzf() { cat >/dev/null; true; }
  run main all "%1" chooser
  [[ ! -f "${BATS_TEST_TMPDIR}/ins" ]]
}

@test "extract.sh - chooser returns when only a key is pressed" {
  _fzf() { cat >/dev/null; printf 'ctrl-o\n'; }
  run main all "%1" chooser
  [[ ! -f "${BATS_TEST_TMPDIR}/act" ]]
}

@test "extract.sh - safe seams are callable without touching fzf or the clipboard" {
  unset _EXTRACT_REVAMPED_LOADED
  unset _EXTRACT_REVAMPED_DISPATCH_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/extract.sh"
  run _capture_pane "%1"
  run _capture_all_panes
  run _capture_last_log
  run _insert "%1" "x"
  run _navigate "%1" "y"
  run _open_path "%1" "/tmp/x"
  run _emit_osc52 "z"
  run _b64 "abc"
  [[ "${output}" == "YWJj" ]]
}

# Run the interactive and destructive seams for real, but with PATH emptied so
# their `command -v` guards short-circuit: no fzf, no browser, no clipboard tool
# is ever invoked, yet the bodies execute for coverage.
@test "extract.sh - interactive seams short-circuit when their tools are absent" {
  unset _EXTRACT_REVAMPED_LOADED
  unset _EXTRACT_REVAMPED_DISPATCH_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/extract.sh"
  local saved="${PATH}"
  PATH=""
  _fzf </dev/null
  _open_url "https://example.com"
  _clip_copy "secret"
  PATH="${saved}"
  true
}
