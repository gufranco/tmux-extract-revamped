<div align="center">

<h1>tmux-extract-revamped</h1>

**Fuzzy-grab any URL, path, or word off the screen and paste it, pure shell, no Python.**

[![Tests](https://github.com/tmux-revamped/tmux-extract-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-extract-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](CHANGELOG.md)

</div>

**13** extractors · **zero Python** · **tmux 1.9 to 3.5** · **open · copy · multi-select** · **95%+** coverage

Press one key, fuzzy-search everything on screen, and the choice lands at your cursor. It captures the pane, pulls out URLs, file paths, words, or whole lines, and shows them in an fzf popup. Unlike extrakto, the extraction is **pure shell**, no Python runtime to install or keep working.

Built from [tmux-plugin-template](https://github.com/tmux-revamped/tmux-plugin-template).

<table>
<tr>
<td><strong>Zero Python</strong><br>URLs, paths, words, and lines are extracted with grep and awk. Nothing to <code>pip install</code>.</td>
<td><strong>Five modes</strong><br>all, urls, paths, words, or lines, each a focused extractor over the captured text.</td>
</tr>
<tr>
<td><strong>Smart candidates</strong><br>Trailing punctuation trimmed, duplicates removed, most specific matches first.</td>
<td><strong>fzf popup</strong><br>Runs in a tmux popup and pastes the choice back into the originating pane.</td>
</tr>
</table>

## Usage

Press `prefix + Tab` to open the picker over the current pane. Type to filter, `Enter` to insert the selection at your cursor. The key, the mode, and the popup size are all configurable.

## Modes

| Mode | Extracts |
|------|----------|
| `all` | URLs, then paths, then words, de-duplicated, most specific first |
| `urls` | http, https, ftp, file URLs and email addresses |
| `paths` | absolute, home, and relative file paths |
| `words` | every whitespace-separated token |
| `lines` | every non-blank line, trimmed |
| `shas` | git-style hex object names, 7 to 40 chars |
| `ipv4` | dotted-quad addresses, octets validated 0 to 255 |
| `ipv6` | full and `::`-compressed IPv6 addresses |
| `color` | CSS hex colors (`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`) |
| `uuid` | canonical 8-4-4-4-12 UUIDs |
| `numbers` | integers and decimals, optional sign |
| `quoted` | values inside single quotes, double quotes, or backticks |
| `bracketed` | values inside `()`, `[]`, `{}`, or `<>` |
| `custom` | matches of `@extract_revamped_custom_regex` |

## Actions

Beyond pasting, bind extra keys to act on the choice. Each is opt-in.

| Action | What it does |
|--------|--------------|
| insert | paste the choice at the cursor (default) |
| navigate | open copy-mode and search for the choice in context |
| open | URL to the browser, path to `$EDITOR`, anything else pasted |
| copy | copy to the clipboard, or over SSH with OSC 52 |
| chooser | in-popup: `ctrl-n` cycles the extractor, `ctrl-o` opens, `ctrl-y` copies, `Enter` inserts |
| doctor | report which optional tools this host has |

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-revamped/tmux-extract-revamped'
```

Press `prefix + I`. Requires [fzf](https://github.com/junegunn/fzf) on the path.

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `@extract_revamped_key` | `Tab` | key that opens the picker |
| `@extract_revamped_navigate_key` | unset | optional key that opens copy-mode and searches for the choice in context |
| `@extract_revamped_open_key` | unset | optional key that opens the choice by type (URL, path, else paste) |
| `@extract_revamped_copy_key` | unset | optional key that copies the choice to the clipboard |
| `@extract_revamped_chooser_key` | unset | optional key for the in-popup action chooser |
| `@extract_revamped_doctor_key` | unset | optional key that prints the capability report |
| `@extract_revamped_mode` | `all` | which extractor the picker uses |
| `@extract_revamped_modes` | `all urls paths words lines` | extractors the chooser cycles through |
| `@extract_revamped_scope` | `pane` | source text: `pane`, `all-panes`, or `last-log` |
| `@extract_revamped_custom_regex` | unset | extended-regex for the `custom` mode |
| `@extract_revamped_min_length` | `0` | drop candidates shorter than this |
| `@extract_revamped_reverse` | `0` | set to `1` to list candidates oldest-first |
| `@extract_revamped_multi` | `0` | set to `1` to allow multi-select, inserted joined |
| `@extract_revamped_osc52` | `0` | set to `1` to copy over SSH with OSC 52 |
| `@extract_revamped_frecency` | `0` | set to `1` to float recently picked candidates to the top |
| `@extract_revamped_lines` | `200` | lines of scrollback to capture |
| `@extract_revamped_popup_width` | `80%` | popup width |
| `@extract_revamped_popup_height` | `60%` | popup height |

## Compatibility

Works on every tmux version with `display-popup`, tmux 3.2 and up for the popup; on older tmux the picker can be wired to a split. Linux (x86_64 and arm64) and macOS (Intel and Apple Silicon). Needs only fzf plus core tmux.

## Development

```bash
make test    # bats suite
make lint    # shellcheck
make coverage  # kcov line coverage on Linux
```

The extractors live in [`src/lib/extract/extract.sh`](src/lib/extract/extract.sh) as pure functions, text in, candidate list out, with the pane capture, the fzf picker, and the paste behind seams so the tests need no pane and no fzf.

## License

[MIT](LICENSE), copyright Gustavo Franco.
