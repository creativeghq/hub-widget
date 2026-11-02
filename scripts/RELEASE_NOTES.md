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
2. Right-click the desktop → **Edit Widgets…** → search **Hub** → add *Hub overview* or *Hub section*.
3. Right-click the widget → **Edit** → paste the key into **API key**. Other Hub widgets reuse it.

Requires macOS 14 Sonoma or later. Runs on Apple silicon and Intel. Full guide in the [README](https://github.com/creativeghq/hub-widget#readme).
