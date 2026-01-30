# menubar-utils

SwiftBar plugins for macOS menu bar.

## Structure

```
├── claude-usage/     # Claude.ai usage monitor (Python)
├── vitals/           # System stats monitor (Swift)
```

## Stack

- **Swift**: vitals plugin, pure Swift with no dependencies
- **Python**: claude-usage plugin, uses `uv` for dependency management

## SwiftBar

- Plugins symlinked to `~/.swiftbar/plugins/`
- Naming: `name.{interval}.{ext}` (e.g., `vitals.5s.swift`)
- Intervals: `s` seconds, `m` minutes, `h` hours, `d` days

## Development

Test Swift plugins directly:
```bash
./vitals/vitals.5s.swift
```

Test Python plugins:
```bash
cd claude-usage && uv run python claude-usage.py
```

## Conventions

- Commits: concise, co-authored with Claude
- No PII in repo (use `$HOME` not absolute paths)
- Git author: `jameson-m@users.noreply.github.com` (local config)
