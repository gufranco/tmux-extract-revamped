#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _EXTRACT_REVAMPED_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/extract/extract.sh"
}

teardown() {
  cleanup_test_environment
}

@test "extract_urls pulls a url and trims trailing punctuation" {
  run extract_urls "go to https://example.com/p, now"
  [[ "${output}" == "https://example.com/p" ]]
}

@test "extract_urls captures emails and de-duplicates" {
  run extract_urls $'mail user@example.com\nmail user@example.com'
  [[ "${output}" == "user@example.com" ]]
}

@test "extract_paths extracts absolute and relative paths" {
  run extract_paths "edit /usr/local/bin/x and ./src/a.sh here"
  [[ "${output}" == *"/usr/local/bin/x"* ]]
  [[ "${output}" == *"./src/a.sh"* ]]
}

@test "extract_words splits on whitespace and de-duplicates" {
  run extract_words "foo bar foo baz"
  [[ "$(printf '%s' "${output}" | grep -c .)" == "3" ]]
}

@test "extract_lines keeps non-blank trimmed lines" {
  run extract_lines $'  hello  \n\n  world'
  [[ "${lines[0]}" == "hello" ]]
  [[ "${lines[1]}" == "world" ]]
}

@test "extract_shas pulls a hex object name and skips plain decimals" {
  run extract_shas "commit 9af2b1cdef on build 1234567 ok"
  [[ "${output}" == *"9af2b1cdef"* ]]
  [[ "${output}" != *"1234567"* ]]
}

@test "extract_shas de-duplicates repeated shas" {
  run extract_shas $'abcdef1 then\nabcdef1 again'
  [[ "${output}" == "abcdef1" ]]
}

@test "extract_ipv4 keeps valid octets and drops out-of-range ones" {
  run extract_ipv4 "host 192.168.1.10 bad 256.1.1.1 done"
  [[ "${output}" == *"192.168.1.10"* ]]
  [[ "${output}" != *"256.1.1.1"* ]]
}

@test "extract_ipv6 matches full and compressed forms but not a clock" {
  run extract_ipv6 "addr fe80::1ff:fe23:4567:890a full 2001:db8:0:0:0:0:0:1 time 12:34:56"
  [[ "${output}" == *"fe80::1ff:fe23:4567:890a"* ]]
  [[ "${output}" == *"2001:db8:0:0:0:0:0:1"* ]]
  [[ "${output}" != *"12:34:56"* ]]
}

@test "extract_hex_colors keeps the longest form first" {
  run extract_hex_colors "fg #aabbccdd bg #f00 mid #1c1c1c"
  [[ "${output}" == *"#aabbccdd"* ]]
  [[ "${output}" == *"#f00"* ]]
  [[ "${output}" == *"#1c1c1c"* ]]
}

@test "extract_uuids matches a canonical uuid" {
  run extract_uuids "id 550e8400-e29b-41d4-a716-446655440000 end"
  [[ "${output}" == "550e8400-e29b-41d4-a716-446655440000" ]]
}

@test "extract_numbers pulls integers and decimals" {
  run extract_numbers "count 42 rate 3.14 neg -7"
  [[ "${output}" == *"42"* ]]
  [[ "${output}" == *"3.14"* ]]
  [[ "${output}" == *"-7"* ]]
}

@test "extract_quoted strips single, double, and backtick delimiters" {
  run extract_quoted $'say "hello world" and \'foo\' run `ls -l`'
  [[ "${output}" == *"hello world"* ]]
  [[ "${output}" == *"foo"* ]]
  [[ "${output}" == *"ls -l"* ]]
}

@test "extract_quoted drops empty quote pairs" {
  run extract_quoted 'empty "" here'
  [[ -z "${output}" ]]
}

@test "extract_bracketed strips paren, square, brace, and angle pairs" {
  run extract_bracketed "f(arg) a[0] {k:v} <tag>"
  [[ "${output}" == *"arg"* ]]
  [[ "${output}" == *"0"* ]]
  [[ "${output}" == *"k:v"* ]]
  [[ "${output}" == *"tag"* ]]
}

@test "extract_custom matches an arbitrary regex" {
  run extract_custom 'TODO-[0-9]+' "see TODO-12 and TODO-99 now"
  [[ "${output}" == *"TODO-12"* ]]
  [[ "${output}" == *"TODO-99"* ]]
}

@test "extract_custom yields nothing for an empty regex" {
  run extract_custom "" "anything at all"
  [[ -z "${output}" ]]
}

@test "extract_min_length drops short candidates" {
  run extract_min_length 2 $'a\nbb\nccc'
  [[ "${output}" != *$'\na'* ]]
  [[ "${lines[0]}" == "bb" ]]
  [[ "${lines[1]}" == "ccc" ]]
}

@test "extract_min_length treats a non-numeric minimum as zero" {
  run extract_min_length "x" $'a\nbb'
  [[ "${lines[0]}" == "a" ]]
  [[ "${lines[1]}" == "bb" ]]
}

@test "extract_reverse flips the line order" {
  run extract_reverse $'a\nb\nc'
  [[ "${lines[0]}" == "c" ]]
  [[ "${lines[1]}" == "b" ]]
  [[ "${lines[2]}" == "a" ]]
}

@test "extract_all combines extractors and de-duplicates across them" {
  run extract_all "https://a.com /path/x word"
  [[ "${output}" == *"https://a.com"* ]]
  [[ "${output}" == *"/path/x"* ]]
  [[ "${output}" == *"word"* ]]
}

@test "extract_regex_escape escapes metacharacters and leaves text alone" {
  [[ "$(extract_regex_escape 'plain')" == "plain" ]]
  [[ "$(extract_regex_escape 'a.b')" == 'a\.b' ]]
  [[ "$(extract_regex_escape 'a+b*c')" == 'a\+b\*c' ]]
  [[ "$(extract_regex_escape '/tmp/x(1)')" == '/tmp/x\(1\)' ]]
  [[ "$(extract_regex_escape 'a|b$')" == 'a\|b\$' ]]
}
