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

- **+ Lead always shows** on the overview, the CRM widget and inside CRM whenever your role can see CRM (1.4.0 could hide it on widgets set up before the update).
- **No more windows:** + Lead now opens a panel that drops down from the Hub icon in the menu bar and closes when you click away. Clicking the Hub icon shows the same panel with your recent notifications, New lead, Open platform, Settings and Updates.
- From 1.4.0: tick off tasks in the widget, the Today tile, every section fits, and a Sections picker in Edit Widget.
