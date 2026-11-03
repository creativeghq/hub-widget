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

- **+ Lead** — on the overview, the CRM widget and inside CRM: opens a small form (name, phone, email, what they want, follow-up date, value) and saves the lead straight to the platform. Also in the menu bar: **New lead…** (⌘L while the menu is open).
- **Tick off tasks** — every task row has a circle; click it and the task is marked done on the platform.
- **Today** — a new first tile: everything dated today plus anything late, across tasks, projects, invoices, leads, deals, viewings and time off.
- **Every section fits** — the large overview shrinks its tiles before it drops a section, so Real estate, Warehouse and HR no longer fall off the end.
- **Choose your sections** — right-click the widget → Edit Widget → *Sections*. Leave it empty to show everything you can see.
- Real estate now lists new enquiries before upcoming viewings.
