# Hub Widget

A macOS desktop widget for the Material KAI platform. It shows what is happening across your
workspace — tasks, projects, finance, quotes, CRM, deals, real estate, warehouse, HR and inbox —
and opens the right page in the web app when you click a figure.

![Build](https://github.com/creativeghq/hub-widget/actions/workflows/build.yml/badge.svg)

## What's new in 1.4.7

- **Icons in the macOS style.** Each area's icon is now a frosted glass tile — light, or graphite in
  dark mode — with its symbol in the area's colour, like the apps in your Dock. Badges are smaller.

In 1.4.6:

- **The widget is a home screen.** Every area is an app icon with its name underneath, in its own
  colour. A red badge shows how many things need you, like on iPhone. Click an icon to go inside and
  see the figures and the list.
- **New: Analytics.** Sales this month against the same days last month, money in and money out,
  sales per day for the last two weeks as a chart, and your top customers this month. The figures
  come from Finance → Reports, so both always agree.
- **macOS glass design.** Panels, buttons and icons use the translucent look of macOS Tahoe, and follow
  the desktop's tinted and clear widget styles.

Earlier versions: [CHANGELOG.md](CHANGELOG.md) · [Download the latest](https://github.com/creativeghq/hub-widget/releases/latest)

```
┌─ Hub overview (large) ─────────────────────────────────┐
│ Hub                        + Lead  ● 4 need attention  │
│ ┌ ✓ My tasks       2 › ┐  ┌ 👥 Leads          3 › ┐    │
│ │ ○ Measure kitchen    │  │ ▍Maria Papadopoulou  │    │
│ │   Overdue · 30 Oct   │  │   Bathroom renovation│    │
│ │ ○ Order worktop      │  │ ▍Nikos Georgiou      │    │
│ │   Today              │  │   Kitchen quote      │    │
│ └──────────────────────┘  └──────────────────────┘    │
│   [☀]²      [▤]       [€]³      [▧]                    │
│   Today   Projects  Finance   Quotes                   │
│   [▥]       [↗]       [⌂]¹      [▣]                    │
│ Analytics  Deals  Real estate Warehouse                │
│   [✉]³                                                 │
│   Inbox                                                │
│ Your workspace                      Updated 2 min ago  │
└────────────────────────────────────────────────────────┘
```

Each icon opens its area inside the widget. **My tasks** opens the task board — **All · Overdue ·
Today · Tomorrow · This week · Later**, tasks as cards you can tick off. **Analytics** opens this
month's figures, a 14-day sales chart and your top customers.

## What you get

| Widget | Sizes | Shows |
|---|---|---|
| **Hub overview** | medium · large · extra large | Every section you can see. Medium: one headline figure per section. Large: up to three per section. Extra large: a card per section. **Click a section** to see its list inside the widget. |
| **Hub section** | small · medium · large | One section you pick in *Edit Widget* — e.g. a small Finance widget next to a small Real estate one. |

- **Orange means attention.** Overdue invoices, overdue tasks, rent overdue, time off waiting for
  approval, myDATA documents not accepted, lead follow-ups due, open inbox conversations. The server
  decides what counts as attention; the widget only colours it.
- **Click to drill down.** In the overview, click a section and the widget shows its list:
  your open tasks, active projects with status and deadline, pending and recently accepted
  quotes with amount, overdue invoices, open deals, upcoming viewings, low-stock items, time off
  to approve, open conversations. Click a row to open that record in the browser; **‹ All** goes
  back (it also returns by itself after 10 minutes).
- **Mac notifications.** Hub Widget sits in the menu bar and turns your platform notifications
  into native macOS notifications — *Quote accepted*, *Task overdue*, *New conversation assigned*
  and everything else your notification bell gets. Clicking one opens the record. The platform's
  Flows decide what you are notified about, so an admin can pause or edit a notification in one
  place for everyone.
- **Designs change without reinstalling.** Section order, how much each size shows, the accent
  colour and an optional banner line come from the platform (`widget_layouts`) and reach every
  widget on its next refresh.
- **Updates itself.** New versions download and install automatically (Sparkle).
- **You only see what you are allowed to see.** A section appears only when your workspace has the
  module *and* your role in it can see that area. A warehouse login does not get a Finance block.
- **Never a fake zero.** If a section could not be read, it says *Unknown* with the reason. If the
  network is down, the widget keeps the last good figures and marks them with a ⚠ and their age.
- **Refresh:** about every 15 minutes (macOS decides the exact moment). Editing the widget, or
  pressing **Check** in the Hub Widget window, refreshes it straight away.

### Sections and figures

| Section | Figures | Opens |
|---|---|---|
| My tasks | Overdue · Due in 7 days · Open (tasks assigned to you) | Projects → My tasks |
| Projects | Active · All projects · next deadlines | Projects |
| Finance | Owed to you · Overdue invoices · myDATA not accepted · Supplier documents to file | Finance → Receivables / Transmissions / Expenses |
| Quotes | Open · New in 30 days | Quotes |
| CRM | Lead follow-ups due · New leads | CRM |
| Deals | Open deals · Weighted pipeline · Closing in 7 days · Past close date | CRM → Pipeline |
| Real estate | Active listings · Viewings in 7 days · New enquiries · Open offers · Rent overdue · Open maintenance | Properties |
| Warehouse | Below reorder point · Lines to receive | Warehouse → Resupply / Inbound |
| HR | Time off to approve · Off today · Employees | HR |
| Inbox | Open conversations | Inbox |

Rent overdue and Open maintenance appear only when the workspace has Property Management.
Money figures show the workspace's main currency; when more than one currency is open the
section says so.

## Requirements

- macOS 14 Sonoma or later (Apple silicon or Intel).
- A platform API key (`kai_…`).
- Nothing else — no Xcode, no Apple account.

## Install

### 1. Download

**[Releases](https://github.com/creativeghq/hub-widget/releases/latest) → `HubWidget-<version>.dmg`.**
Open it and drag **Hub Widget** onto **Applications**.

Or from a terminal, with the GitHub CLI signed in (`brew install gh && gh auth login`):

```bash
gh repo clone creativeghq/hub-widget && ./hub-widget/scripts/install.sh
```

That downloads the latest release into `/Applications`, clears the quarantine flag and opens it.

### 2. Allow it to open (once)

The build is signed ad-hoc, not with a paid Apple Developer account, so macOS blocks the first
launch of a downloaded copy. Either run

```bash
xattr -dr com.apple.quarantine "/Applications/Hub Widget.app"
```

or double-click it, press **Done**, then **System Settings → Privacy & Security → Open Anyway**.
(`install.sh` does this for you.)

### 3. Create an API key and connect the app

In the web app: **Profile → Keys → Generate key** (the Hub Widget window has a button for it).

- Name it e.g. *Mac widget*.
- Bind it to the workspace you want to watch (recommended — the key can then read nothing else).
- If you restrict endpoints, allow `/functions/v1/workspace-pulse`.
- Copy the key — it is shown **once**.

The key acts as you: the widget sees exactly what you see in the app, never more. The endpoint
is read-only and costs no credits.

Paste the key into the Hub Widget window → **Connect**. That turns on Mac notifications (allow them
when macOS asks), sets Hub Widget to open at login, and shows a preview of what the widget will
display. Later, open the window from the menu-bar icon → **Settings…**.

### 4. Add the widget

1. Right-click the desktop → **Edit Widgets…** (or Notification Centre → *Edit Widgets*).
2. Search **Hub**, drag *Hub overview* or *Hub section* onto the desktop.
3. Optional: right-click the widget → **Edit "Hub overview"** to pick a *Workspace* or, for
   *Hub section*, the **Section**.

The widget uses the key saved in the app's **Settings…** — there is no App Group without a paid
Apple Developer account, so the app writes it to `~/Library/Application Support/HubWidget/key`,
which both sandboxes may reach by a temporary exception. The **API key** field in Edit Widget is
optional; a key there is tried first, and if it is refused the widget falls back to the app's key.

Keep **Hub Widget.app** in `/Applications` — clicking a figure in the widget opens the page in
your browser through it. It does not need to stay open.

### Updating

Automatic. Hub Widget checks for a new version every 6 hours and installs it in the background
(menu-bar icon → **Check for updates…** to do it now). Widgets and their settings are kept.
Only **1.0.0**, which predates auto-update, has to be replaced by hand once.

## How it works

```
 Widget (WidgetKit, sandboxed)          Hub Widget.app (menu bar, opens at login)
        │  key + workspace from "Edit Widget"     polls ?view=notifications every minute →
        │                                         native macOS notifications; opens clicked
        │                                         links in the browser; Sparkle auto-update
        ▼  GET /functions/v1/workspace-pulse   Authorization: Bearer kai_…
 Supabase edge function  workspace-pulse
        │  resolves the workspace, runs as the key's owner (RLS applies)
        ▼
 SQL  get_workspace_pulse(workspace_id)  — every figure derived in the database
```

The widget does no arithmetic on business data. Counts, money, what is "overdue" and what needs
attention are all decided by `get_workspace_pulse` on the platform, so the widget can never
disagree with the web app.

### Response shape

```jsonc
{
  "ok": true,
  "workspace": { "id": "…", "name": "Acme" },
  "as_of": "2026-11-02T17:50:36+00:00",
  "attention": 4,                           // figures currently flagged
  "sections": [{
    "key": "finance", "title": "Finance", "status": "ok",   // or "failed" + note
    "url": "/finance?tab=ar", "note": null,
    "metrics": [{ "key": "receivables", "label": "Owed to you", "value": 48250,
                  "kind": "money", "currency": "EUR", "tone": "neutral", "url": "/finance?tab=ar" }],
    "items": [{ "title": "Kitchen", "subtitle": "in_progress", "date": "2026-11-20", "url": "/projects" }]
  }],
  "unavailable": [{ "key": "hr", "title": "HR", "reason": "not_entitled" }],  // or no_capability
  "workspaces": [{ "id": "…", "name": "Acme" }]
}
```

Try it from a terminal:

```bash
curl -s https://bgbavxtjlbvgplozizxu.supabase.co/functions/v1/workspace-pulse \
  -H "Authorization: Bearer kai_YOUR_KEY" | jq .
# another workspace you belong to:
curl -s "…/workspace-pulse?workspace_id=<uuid>" -H "Authorization: Bearer kai_YOUR_KEY"
```

Workspace choice: `workspace_id` if given, else the workspace the key is bound to, else the one you
joined most recently. A workspace you are not in returns **404**.

## Project layout

```
project.yml                 XcodeGen spec — the .xcodeproj is generated, not committed
Config/Signing.xcconfig     includes Config/Local.xcconfig (your DEVELOPMENT_TEAM, git-ignored)
Shared/                     compiled into both targets
  PulseModels.swift         Codable types for the response
  PulseClient.swift         the HTTP call + offline cache
  HubStore.swift            addresses, remembered key, offline cache
  Formatting.swift          number/money/date formatting, section icons
  SamplePulse.swift         placeholder data for the widget gallery only
HubWidget/                  the app: settings window, deep-link handler
HubWidgetExtension/         the widgets: timeline providers, views, section picker
Tests/                      decoding/formatting tests against a recorded response
scripts/install.sh          download the latest release into /Applications
scripts/INSTALL.txt         the guide shipped inside the .dmg
.github/workflows/          build.yml (every push), release.yml (tags → .dmg/.zip release)
```

## Development

```bash
brew install xcodegen
xcodegen generate                  # re-run after editing project.yml or adding files
open HubWidget.xcodeproj
```

- Widget previews: open `HubWidgetExtension/HubWidgets.swift` and use the canvas (sample data).
- Run the widget in Xcode: choose the **HubWidgetExtension** scheme → Run → pick a widget family.
- Tests: `xcodebuild -project HubWidget.xcodeproj -scheme HubWidget -destination 'platform=macOS' test`
- CI (`.github/workflows/build.yml`) builds unsigned and runs the tests on every push.
- Building your own signed copy: put `DEVELOPMENT_TEAM = <your team id>` in `Config/Local.xcconfig`,
  then Product → Archive in Xcode.

### Adding a figure or a section

Figures come from the platform, not from this repo. Add it to `public.get_workspace_pulse` in the
platform database (a `pulse_metric(...)` entry in the right section) and every installed widget
shows it on its next refresh, no new build. A brand-new **section** also needs its key added
to `SectionKind` (for the section picker) and to `SectionStyle.symbol` (its icon).

### Changing the design (no new build)

The design lives in the platform table `widget_layouts`: one row `scope = 'default'` for everyone,
plus optional rows keyed by a workspace id that override it. Platform admins can write it; every
widget reads it on its next refresh.

```jsonc
{
  "attention_color": "#F59E0B",                 // what "needs attention" is drawn in
  "banner": {"text": "Month-end: issue invoices", "tone": "attention", "url": "/finance?tab=ar"},  // or null
  "order": ["finance", "quotes", "projects", "tasks", "deals", "realestate", "warehouse", "hr", "crm", "inbox"],
  "overview": {
    "medium":      {"max_sections": 6, "columns": 3},
    "large":       {"max_sections": 6, "metrics": 3},
    "extra_large": {"max_sections": 12, "columns": 3, "metrics": 3, "items": 0}
  },
  "section":  {"small": {"metrics": 3}, "medium": {"metrics": 3, "items": 2}, "large": {"metrics": 6, "items": 6}},
  "drilldown": {"items": 6}
}
```

```sql
update public.widget_layouts
   set layout = jsonb_set(layout, '{banner}', '{"text":"Month-end: issue invoices","tone":"attention","url":"/finance?tab=ar"}')
 where scope = 'default';
```

Every number is capped by the app to what fits that widget size (`FitLimits`), so a layout can
restyle the widget but never make it overflow. A new building block (a chart, a new card style)
is an app change and ships through auto-update.

## Troubleshooting

| You see | Do this |
|---|---|
| No Mac notifications | Menu-bar icon → Settings…: the key is connected and *Show Mac notifications* is on; System Settings → Notifications → Hub Widget is allowed; *Open at login* is on (notifications need the app running). |
| No menu-bar icon | Open Hub Widget from Applications once; it then starts at login. |
| "Open the Hub app → Settings…" | No key yet: paste it in the app's Settings. |
| "The API key was refused" | The key was revoked or expired — generate a new one in Profile → Keys and save it in the app's Settings. |
| "Workspace not found for this key" | The key is bound to another workspace, or you left it. Clear *Workspace* in Edit Widget, or use a key bound to the right one. |
| "Hub Widget can't be opened" / "Apple could not verify…" | First launch of an ad-hoc build — see Install step 2. |
| A section says *Unknown* | The platform could not read that section; the note says why. Other sections are unaffected. |
| ⚠ next to "Last good …" | The latest refresh failed (offline, VPN, platform down). Figures are from the time shown. |
| A blank square instead of the app icon on Mac banners | macOS cached the icon before it existed. In Terminal: `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Hub Widget.app" && killall NotificationCenter` — the next banner shows the MH icon. |
| Clicking a figure does nothing | Hub Widget.app must be in `/Applications`; open it once so macOS registers its `hubwidget://` links. |
| Widget missing from the gallery | Open the app once after installing, then log out/in if macOS still has not picked it up. |
| A section you expect is missing | Check the key in the Hub Widget window: the preview lists hidden sections with the reason (module not in the workspace, or your role cannot see it). |

## Security

- The key is saved by the app (Settings…) in its sandboxed preferences and in
  `~/Library/Application Support/HubWidget/key` (owner-only), which is how the widgets read it. A key
  typed into a widget's *Edit Widget* is kept by macOS for that widget. It is sent only to the
  platform API over HTTPS.
- Both the app and the widget are sandboxed with outgoing network access only.
- The endpoint is read-only and runs as the key's owner, so database row security applies exactly
  as in the web app. A key bound to a workspace cannot read any other.
- To revoke: delete the widget and revoke the key in Profile → Keys.
- Builds are signed ad-hoc (no Apple Developer account). Each release lists SHA-256 checksums
  (`SHA256SUMS.txt`); compare with `shasum -a 256 HubWidget-*.dmg`.

## Releasing a new version

1. Add a `## <version> — <date>` entry at the top of [CHANGELOG.md](CHANGELOG.md), in plain words
   for the people using the widget, and copy it into *What's new* at the top of this README.
2. Push a tag — `git tag v1.4.6 && git push origin v1.4.6` — or run **Actions → Release → Run
   workflow** with a version.

The workflow builds a universal (Apple silicon + Intel) app, packages `HubWidget-<version>.dmg` and
`.zip` with checksums, and publishes the GitHub Release. The release page opens with the version's
CHANGELOG entry, then the install steps (`scripts/RELEASE_NOTES.md`); a tag with no CHANGELOG entry
fails the release rather than publishing one without notes.

## License

CC0 1.0 — see [LICENSE](LICENSE).
