#!/usr/bin/env bash
#
# extract.sh: pure token extractors for tmux-extract-revamped.
#
# Each extractor turns captured pane text into a newline-separated, de-duplicated
# list of candidates. They are pure: text in, list out, no pane and no fzf. The
# pane capture and the picker sit behind seams in the dispatcher. No temp files.

[[ -n "${_EXTRACT_REVAMPED_LOADED:-}" ]] && return 0
_EXTRACT_REVAMPED_LOADED=1

# extract_urls TEXT -> http(s), ftp, file, and git URLs, trailing punctuation
# trimmed, de-duplicated in first-seen order.
extract_urls() {
  printf '%s\n' "${1}" \
    | grep -oE '(https?|ftp|file)://[A-Za-z0-9._~:/?#@!$&'"'"'()*+,;=%-]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | sed -E 's/[].,;:)}>"'"'"']+$//' \
    | awk 'NF && !seen[$0]++'
}

# extract_paths TEXT -> absolute, home, and relative file paths, de-duplicated.
extract_paths() {
  printf '%s\n' "${1}" \
    | grep -oE '(~|\.{1,2})?/[A-Za-z0-9._/-]+|[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+' \
    | sed -E 's/[].,;:)}>"'"'"']+$//' \
    | awk 'NF && !seen[$0]++'
}

# extract_words TEXT -> whitespace-separated tokens, de-duplicated.
extract_words() {
  printf '%s\n' "${1}" \
    | tr '[:space:]' '\n' \
    | awk 'NF && !seen[$0]++'
}

# extract_lines TEXT -> non-blank lines, leading and trailing spaces trimmed.
extract_lines() {
  printf '%s\n' "${1}" \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | awk 'NF && !seen[$0]++'
}

# extract_shas TEXT -> git-style hex object names, 7 to 40 hex chars with at
# least one a-f letter so plain decimals fall to the numbers extractor instead.
extract_shas() {
  printf '%s\n' "${1}" \
    | grep -oiE '[0-9a-f]{7,40}' \
    | grep -iE '[a-f]' \
    | awk 'NF && !seen[$0]++'
}

# extract_ipv4 TEXT -> dotted-quad addresses, each octet validated 0 to 255.
extract_ipv4() {
  printf '%s\n' "${1}" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | awk -F. '$1<=255 && $2<=255 && $3<=255 && $4<=255 && !seen[$0]++'
}

# extract_ipv6 TEXT -> IPv6 addresses, full and "::"-compressed forms. Clock-like
# "12:34:56" never matches: it has no "::" and fewer than seven colons.
extract_ipv6() {
  printf '%s\n' "${1}" \
    | grep -oiE '([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}|([0-9a-f]{1,4}:){1,7}:|([0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}|([0-9a-f]{1,4}:){1,5}(:[0-9a-f]{1,4}){1,2}|([0-9a-f]{1,4}:){1,4}(:[0-9a-f]{1,4}){1,3}|([0-9a-f]{1,4}:){1,3}(:[0-9a-f]{1,4}){1,4}|([0-9a-f]{1,4}:){1,2}(:[0-9a-f]{1,4}){1,5}|[0-9a-f]{1,4}:(:[0-9a-f]{1,4}){1,6}|:(:[0-9a-f]{1,4}){1,7}' \
    | awk 'NF && !seen[$0]++'
}

# extract_hex_colors TEXT -> CSS hex colors (#rgb, #rgba, #rrggbb, #rrggbbaa),
# longest form first so "#aabbccdd" is not truncated to six digits.
extract_hex_colors() {
  printf '%s\n' "${1}" \
    | grep -oiE '#([0-9a-f]{8}|[0-9a-f]{6}|[0-9a-f]{4}|[0-9a-f]{3})' \
    | awk 'NF && !seen[$0]++'
}

# extract_uuids TEXT -> canonical 8-4-4-4-12 UUIDs, case-insensitive.
extract_uuids() {
  printf '%s\n' "${1}" \
    | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | awk 'NF && !seen[$0]++'
}

# extract_numbers TEXT -> integers and decimals, optional leading sign.
extract_numbers() {
  printf '%s\n' "${1}" \
    | grep -oE '[-+]?[0-9]+(\.[0-9]+)?' \
    | awk 'NF && !seen[$0]++'
}

# extract_quoted TEXT -> values inside single quotes, double quotes, or
# backticks, with the surrounding delimiter stripped. Empty pairs are dropped.
extract_quoted() {
  printf '%s\n' "${1}" \
    | grep -oE '"[^"]*"'"|'[^']*'|"'`[^`]*`' \
    | sed -E 's/^.(.*).$/\1/' \
    | awk 'NF && !seen[$0]++'
}

# extract_bracketed TEXT -> values inside (), [], {}, or <>, brackets stripped.
extract_bracketed() {
  printf '%s\n' "${1}" \
    | grep -oE '\([^()]*\)|\[[^][]*\]|\{[^{}]*\}|<[^<>]*>' \
    | sed -E 's/^.(.*).$/\1/' \
    | awk 'NF && !seen[$0]++'
}

# extract_custom REGEX TEXT -> matches of an arbitrary extended-regex. The empty
# REGEX yields nothing so a misconfigured custom mode never pulls the whole pane.
extract_custom() {
  local re="${1}"
  [[ -z "${re}" ]] && return 0
  printf '%s\n' "${2}" \
    | grep -oE "${re}" 2>/dev/null \
    | awk 'NF && !seen[$0]++'
}

# extract_all TEXT -> urls, then paths, then words, de-duplicated across all three
# so the most specific candidates sort first.
extract_all() {
  { extract_urls "${1}"; extract_paths "${1}"; extract_words "${1}"; } | awk 'NF && !seen[$0]++'
}

# extract_min_length MIN TEXT -> only lines at least MIN characters long. A
# non-numeric MIN is treated as zero so the picker never silently empties.
extract_min_length() {
  local min="${1:-0}"
  case "${min}" in '' | *[!0-9]*) min=0 ;; esac
  printf '%s\n' "${2}" | awk -v m="${min}" 'NF && length($0) >= m'
}

# extract_reverse TEXT -> the lines in reverse order (oldest-on-screen first).
extract_reverse() {
  printf '%s\n' "${1}" | awk 'NF{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}'
}

# extract_regex_escape STR -> STR with extended-regex metacharacters
# backslash-escaped, so a selected candidate used as a copy-mode search pattern
# matches its literal text rather than acting as a regex. Pure bash, so it is
# identical on every platform.
extract_regex_escape() {
  local s="${1}" out="" ch i
  for ((i = 0; i < ${#s}; i++)); do
    ch="${s:i:1}"
    case "${ch}" in
      '.' | '\' | '[' | ']' | '(' | ')' | '{' | '}' | '*' | '+' | '?' | '|' | '^' | '$')
        out+="\\${ch}" ;;
      *) out+="${ch}" ;;
    esac
  done
  printf '%s' "${out}"
}

export -f extract_urls
export -f extract_paths
export -f extract_words
export -f extract_lines
export -f extract_shas
export -f extract_ipv4
export -f extract_ipv6
export -f extract_hex_colors
export -f extract_uuids
export -f extract_numbers
export -f extract_quoted
export -f extract_bracketed
export -f extract_custom
export -f extract_all
export -f extract_min_length
export -f extract_reverse
export -f extract_regex_escape
