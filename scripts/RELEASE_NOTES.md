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

## What's new

- **MH logo in the menu bar** instead of the grid symbol, with the unread count next to it.
- **New lead from the menu bar shows every field** — the panel now resizes to the form (it kept the small size it opened at, so only Name fit).
- **A refused API key is said out loud.** When the widget's key has been replaced, the widget now tells you to paste the new one instead of quietly showing old figures.
- **Mac notifications work again** — the timestamp the app sent lost its `+` on the way, so every check was refused.
