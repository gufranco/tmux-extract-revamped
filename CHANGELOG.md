# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-06-30

### Added

- Eight new extractors: git SHAs, IPv4 addresses (octet-validated), IPv6
  addresses (full and `::`-compressed), CSS hex colors, UUIDs, numbers, quoted
  values, and bracketed values. Each is a pure grep + awk function.
- Custom regex mode (`@extract_revamped_custom_regex`) for one-off patterns.
- Candidate tuning: minimum length (`@extract_revamped_min_length`) and reverse
  order (`@extract_revamped_reverse`).
- Open action: opening a URL launches the browser, a path opens in `$EDITOR`,
  anything else is pasted. Bind with `@extract_revamped_open_key`.
- Copy action: copy the choice to the clipboard, or over SSH with OSC 52 when
  `@extract_revamped_osc52` is set. Bind with `@extract_revamped_copy_key`.
- Multi-select (`@extract_revamped_multi`): mark several candidates and insert
  them joined.
- In-popup action chooser (`@extract_revamped_chooser_key`): cycle the extractor
  with `ctrl-n`, open with `ctrl-o`, copy with `ctrl-y`, insert with `Enter`,
  without rebinding.
- Wider grab area (`@extract_revamped_scope`): `all-panes` mines every pane in
  the window, `last-log` mines the newest tmux-logging-revamped capture.
- Frecency (`@extract_revamped_frecency`): recently picked candidates float to
  the top, stored in a tmux option with no temp file.
- Doctor report (`@extract_revamped_doctor_key`): shows which optional tools
  (fzf, opener, clipboard, base64) this host has.

## [1.1.0] - 2026-06-23

### Added

- Optional navigate action: bind `@extract_revamped_navigate_key` to open the
  picker and, instead of pasting the choice, jump to it in copy-mode so you can
  read it in its surrounding context. The search term is regex-escaped so it
  matches literally (upstream extrakto #130).

## [1.0.0] - 2026-06-22

### Added

- Fuzzy-extract URLs, file paths, words, or whole lines from a pane and paste
  the choice at the cursor, in an fzf popup.
- Pure-shell extraction with grep and awk, no Python runtime to install.
- Five modes (all, urls, paths, words, lines) with trailing punctuation trimmed,
  duplicates removed, and the most specific candidates first.
- Configurable key, mode, scrollback depth, and popup size.
