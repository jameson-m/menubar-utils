# menubar-utils

SwiftBar plugins for macOS menu bar.

## Structure

```
├── claude-usage/     # Claude.ai usage monitor (Go)
├── vitals/           # System stats monitor (Swift)
├── justfile          # Build/install commands
```

## Stack

- **Swift**: vitals plugin, pure Swift with no dependencies
- **Go**: claude-usage plugin, compiles to standalone binary
- **just**: command runner for build/install

## Config

- Plugins: `~/.swiftbar/plugins/`
- Credentials: `~/.config/menubar-utils/`

## Development

```bash
just          # Show available commands
just build    # Build Go plugins
just test     # Test plugin output
just install  # Build and symlink to SwiftBar
```

Test plugins directly:
```bash
./vitals/vitals.5s.swift
./claude-usage/claude-usage.1m
```

## SwiftBar

- Naming: `name.{interval}.{ext}` (e.g., `vitals.5s.swift`)
- Intervals: `s` seconds, `m` minutes, `h` hours, `d` days

## Conventions

- Commits: concise, co-authored with Claude
- No PII in repo (use generic paths like `~/.config/`)
