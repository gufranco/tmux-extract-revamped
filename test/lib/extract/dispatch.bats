#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _EXTRACT_REVAMPED_DISPATCH_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/extract/dispatch.sh"
}

teardown() {
  cleanup_test_environment
}

@test "dispatch.sh - functions are defined" {
  function_exists classify_target
  function_exists join_selection
  function_exists first_line
  function_exists next_mode
  function_exists parse_expect_key
  function_exists parse_expect_rest
  function_exists osc52_sequence
  function_exists frecency_reorder
  function_exists doctor_report
}

@test "classify_target recognizes scheme urls" {
  [[ "$(classify_target 'https://a.com')" == "url" ]]
  [[ "$(classify_target 'ftp://a.com')" == "url" ]]
  [[ "$(classify_target 'file:///x')" == "url" ]]
}

@test "classify_target recognizes path prefixes" {
  [[ "$(classify_target '/etc/hosts')" == "path" ]]
  [[ "$(classify_target '~/x')" == "path" ]]
  [[ "$(classify_target './a')" == "path" ]]
  [[ "$(classify_target '../b')" == "path" ]]
}

@test "classify_target treats an email-like token as a url" {
  [[ "$(classify_target 'user@host.com')" == "url" ]]
}

@test "classify_target treats a bare slash token as a path" {
  [[ "$(classify_target 'src/app.ts')" == "path" ]]
}

@test "classify_target falls back to other" {
  [[ "$(classify_target 'justaword')" == "other" ]]
}

@test "join_selection joins non-blank lines with the separator" {
  [[ "$(join_selection ' ' $'a\nb\nc')" == "a b c" ]]
  [[ "$(join_selection ',' $'a\n\nb')" == "a,b" ]]
}

@test "first_line returns the first non-blank line" {
  [[ "$(first_line $'\n  \nhello\nworld')" == "hello" ]]
}

@test "next_mode advances and wraps" {
  [[ "$(next_mode all 'all urls paths')" == "urls" ]]
  [[ "$(next_mode paths 'all urls paths')" == "all" ]]
}

@test "next_mode falls back to the first for an unknown current" {
  [[ "$(next_mode zzz 'all urls paths')" == "all" ]]
}

@test "parse_expect_key and parse_expect_rest split fzf --expect output" {
  out=$'ctrl-o\nfoo\nbar'
  [[ "$(parse_expect_key "${out}")" == "ctrl-o" ]]
  [[ "$(parse_expect_rest "${out}")" == $'foo\nbar' ]]
}

@test "osc52_sequence wraps the payload in the OSC 52 escape" {
  run osc52_sequence "QUJD"
  [[ "${output}" == *"]52;c;QUJD"* ]]
}

@test "frecency_reorder floats recent picks to the top" {
  run frecency_reorder $'b\nc' $'a\nb\nc\nd'
  [[ "${lines[0]}" == "b" ]]
  [[ "${lines[1]}" == "c" ]]
  [[ "${lines[2]}" == "a" ]]
  [[ "${lines[3]}" == "d" ]]
}

@test "frecency_reorder leaves order intact with empty recent" {
  run frecency_reorder "" $'a\nb\nc'
  [[ "${lines[0]}" == "a" ]]
  [[ "${lines[1]}" == "b" ]]
  [[ "${lines[2]}" == "c" ]]
}

@test "doctor_report prints the capability lines" {
  run doctor_report yes no yes no
  [[ "${output}" == *"tmux-extract-revamped doctor"* ]]
  [[ "${output}" == *"fzf picker:"* ]]
  [[ "${output}" == *"url opener:"* ]]
  [[ "${output}" == *"clipboard:"* ]]
  [[ "${output}" == *"base64 (osc52):"* ]]
}
