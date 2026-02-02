# claude-usage

SwiftBar plugin to monitor Claude.ai usage limits.

**Menu bar:** `C: 13%/10%` (session % / weekly %)

## Status Indicators

| Display | Meaning |
|---------|---------|
| `C: 13%/10%` | Normal - session/weekly usage |
| Orange | Usage >80% |
| Red | Usage >95% |
| `C: AUTH` | Session expired - need new cookie |
| `C: --/--` | Network error |
| `C: CFG` | Missing or invalid config |

## Configuration

Config file: `~/.config/menubar-utils/claude-usage.env`

```
CLAUDE_ORG_ID=your-org-id-here
CLAUDE_SESSION_KEY=sk-ant-sid01-...
```

See the [main README](../README.md#getting-credentials) for how to get these values.

## Development

```bash
# Build
go build -o claude-usage.1m main.go

# Test
./claude-usage.1m
```

## Auth Expiration

The session cookie expires periodically. When you see `C: AUTH`:

1. Log into claude.ai in browser
2. Copy new `sessionKey` from DevTools → Application → Cookies
3. Click "Edit config" in dropdown or run `just config`
