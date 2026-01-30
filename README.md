# menubar-utils

A collection of [SwiftBar](https://github.com/swiftbar/SwiftBar) plugins for macOS.

## Plugins

### vitals

System monitor showing CPU, GPU, RAM, and swap usage with progress bars.

**Menu bar:** Memory usage with pressure-colored icon

**Dropdown:**
- CPU/GPU/RAM usage with visual progress bars
- Color coded: green → yellow → orange → red
- Memory breakdown (app, wired, compressed, cached)
- Swap usage
- Thermal state
- System info and uptime

### claude-usage

Monitor your [Claude.ai](https://claude.ai) usage limits.

**Menu bar:** Session and weekly usage percentages

**Dropdown:**
- Detailed token counts
- Reset times
- Quick link to edit credentials

## Installation

1. Install [SwiftBar](https://github.com/swiftbar/SwiftBar)
   ```bash
   brew install swiftbar
   ```

2. Clone this repo
   ```bash
   git clone https://github.com/jameson-m/menubar-utils.git
   ```

3. Symlink desired plugins to your SwiftBar plugins folder
   ```bash
   ln -s /path/to/menubar-utils/vitals/vitals.5s.swift ~/.swiftbar/plugins/
   ln -s /path/to/menubar-utils/claude-usage/claude-usage.1m.sh ~/.swiftbar/plugins/
   ```

4. For claude-usage, set up credentials (see [claude-usage/README.md](claude-usage/README.md))

## Requirements

- macOS (tested on Apple Silicon)
- SwiftBar
- For vitals: Swift (included with Xcode/Command Line Tools)
- For claude-usage: Python 3.11+, [uv](https://github.com/astral-sh/uv)

## License

MIT
