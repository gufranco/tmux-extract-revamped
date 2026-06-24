<div align="center">

<h1>tmux-extract-revamped</h1>

**Fuzzy-grab any URL, path, or word off the screen and paste it, pure shell, no Python.**

[![Tests](https://github.com/gufranco/tmux-extract-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/gufranco/tmux-extract-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](CHANGELOG.md)

</div>

**5** extractors · **zero Python** · **tmux 1.9 to 3.5** · **38** tests · **95%+** coverage

Press one key, fuzzy-search everything on screen, and the choice lands at your cursor. It captures the pane, pulls out URLs, file paths, words, or whole lines, and shows them in an fzf popup. Unlike extrakto, the extraction is **pure shell**, no Python runtime to install or keep working.

Built from [tmux-plugin-template](https://github.com/gufranco/tmux-plugin-template).

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

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```tmux
set -g @plugin 'gufranco/tmux-extract-revamped'
```

Press `prefix + I`. Requires [fzf](https://github.com/junegunn/fzf) on the path.

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `@extract_revamped_key` | `Tab` | key that opens the picker |
| `@extract_revamped_navigate_key` | unset | optional key that, instead of pasting, opens copy-mode and searches for the choice so you can read it in context |
| `@extract_revamped_mode` | `all` | which extractor the picker uses |
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
