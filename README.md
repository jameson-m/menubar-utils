# Claude.ai Usage Monitor

Mac menu bar app showing claude.ai plan usage with 1-minute refresh.

Displays: `C: 13%/10%` (session % / weekly %)

## Setup

### 1. Install SwiftBar

```bash
brew install --cask swiftbar
```

### 2. Install dependencies

```bash
cd /path/to/claude-usage
uv sync
```

### 3. Get credentials from claude.ai

1. Go to [claude.ai](https://claude.ai) and log in
2. Open DevTools (Cmd+Option+I)
3. Go to **Application** > **Cookies** > `https://claude.ai`
4. Copy the `sessionKey` value (starts with `sk-ant-sid01-...`)
5. Go to **Settings** > **Usage** and check Network tab for any request
6. Find your org ID in the URL: `/api/organizations/{org_id}/usage`

### 4. Configure credentials

```bash
cp .env.example .env
# Edit .env with your credentials
```

### 5. Install plugin

Symlink the wrapper script to your SwiftBar plugins folder:

```bash
ln -s /path/to/claude-usage/claude-usage.1m.sh ~/Library/Application\ Support/SwiftBar/Plugins/
```

## Display

- `C: 13%/10%` - session usage / weekly usage
- Orange when >80%
- Red when >95%
- `C: AUTH` - session expired, need new cookie
- `C: --/--` - network error
- `C: CFG` - missing env vars

## Auth Expiration

The session cookie expires periodically. When you see `C: AUTH`:

1. Log into claude.ai in browser
2. Copy new `sessionKey` from DevTools
3. Click "Edit .env" in dropdown (or edit `.env` directly)
