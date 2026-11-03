## Download

**HubWidget-*.dmg** — open it, drag Hub Widget to Applications. (`.zip` holds the same app.)

## First launch (once)

This build is not signed with an Apple Developer account, so macOS blocks it the first time. Run:

```bash
xattr -dr com.apple.quarantine "/Applications/Hub Widget.app"
```

…or open it, press **Done**, then **System Settings → Privacy & Security → Open Anyway**.

## Set up

1. Web app → **Profile → Keys → Generate key** (bind it to your workspace, copy it).
2. Open **Hub Widget** → **Settings…** → paste the key. Every Hub widget uses this key.
3. Right-click the desktop → **Edit Widgets…** → search **Hub** → add *Hub overview* or *Hub section*.

Requires macOS 14 Sonoma or later. Runs on Apple silicon and Intel. Full guide in the [README](https://github.com/creativeghq/hub-widget#readme).

## What's new

- **One key for the app and every widget.** The key saved in the app's Settings now reaches the widgets too. A widget that still holds an old key from Edit Widget falls back to the app's key instead of showing "API key was refused".
