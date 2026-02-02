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
- Usage percentages with reset times
- Quick link to edit credentials

## Requirements

- macOS (tested on Apple Silicon)
- [SwiftBar](https://github.com/swiftbar/SwiftBar)
- [just](https://github.com/casey/just) (command runner)
- For vitals: Swift (included with Xcode CLI tools)
- For claude-usage: [Go](https://go.dev/)

## Installation

1. Install dependencies

   ```bash
   brew install swiftbar just go
   ```

2. Clone and install

   ```bash
   git clone https://github.com/jameson-m/menubar-utils.git
   cd menubar-utils
   just install
   ```

3. Configure claude-usage credentials (see [Getting Credentials](#getting-credentials))

   ```bash
   just config  # opens ~/.config/menubar-utils/
   ```

4. Launch SwiftBar and select `~/.swiftbar/plugins/` as the plugins folder

## Getting Credentials

For the claude-usage plugin, you need your Claude.ai session credentials:

1. Go to [claude.ai](https://claude.ai) and log in
2. Open DevTools (Cmd+Option+I)
3. Go to **Application** → **Cookies** → `https://claude.ai`
4. Copy the `sessionKey` value (starts with `sk-ant-sid01-...`)
5. Go to **Settings** → **Usage** and open the Network tab
6. Find your org ID in any API request URL: `/api/organizations/{org_id}/usage`

Edit `~/.config/menubar-utils/claude-usage.env` with these values.

## Commands

```bash
just          # Show available commands
just build    # Build plugins
just install  # Build and install to SwiftBar
just uninstall # Remove from SwiftBar
just config   # Open config directory
just test     # Test plugin output
just clean    # Remove build artifacts
```

## License

MIT
