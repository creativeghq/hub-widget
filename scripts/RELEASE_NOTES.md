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

- The app reports its real version, so the updater stops offering the same update again (1.2.0 called itself 1.0).

- Click a section in the overview to see its list inside the widget — tasks, projects, pending quotes, invoices, deals, viewings and more. Click a row to open it.
- Native Mac notifications for your platform notifications (quote accepted, task overdue, new conversation…). Hub Widget now lives in the menu bar and opens at login.
- The widget measures what fits instead of guessing: nothing is ever cut off. The large overview is now a 2-column tile grid, with sections needing attention first.
- Updates install automatically from now on. (Coming from 1.0.0: replace the app by hand this one time.)
