# Hub Widget

A macOS desktop widget for the Material KAI platform. It shows what is happening across your
workspace — tasks, projects, finance, quotes, CRM, deals, real estate, warehouse, HR and inbox —
and opens the right page in the web app when you click a figure.

![Build](https://github.com/creativeghq/hub-widget/actions/workflows/build.yml/badge.svg)

```
┌─ Hub overview (large) ──────────────────────────────┐
│ Hub                               4 need attention  │
│ ✓ My tasks     ● 2 Overdue   5 Due in 7 days  14 Open│
│ ▤ Projects       6 Active   21 All projects          │
│ € Finance      €48K Owed to you  ● 3 Overdue invoices│
│ ↗ Deals          9 Open deals  €126K Weighted        │
│ ⌂ Real estate   17 Active listings  4 Viewings       │
│ ▣ Warehouse      0 Below reorder  8 Lines to receive │
│ ✉ Inbox        ● 3 Open conversations                │
│ Your workspace                     Updated 2 min ago │
└──────────────────────────────────────────────────────┘
```

## What you get

| Widget | Sizes | Shows |
|---|---|---|
| **Hub overview** | medium · large · extra large | Every section you can see. Medium shows one headline figure per section; large shows up to three per section; extra large shows every figure plus upcoming items (e.g. the next project deadlines). |
| **Hub section** | small · medium · large | One section you pick in *Edit Widget* — e.g. a small Finance widget next to a small Real estate one. |

- **Orange means attention.** Overdue invoices, overdue tasks, rent overdue, time off waiting for
  approval, myDATA documents not accepted, lead follow-ups due, open inbox conversations. The server
  decides what counts as attention; the widget only colours it.
- **Click to open.** Every section and figure opens its page in the web app
  (e.g. *Overdue invoices* → Finance → Receivables).
- **You only see what you are allowed to see.** A section appears only when your workspace has the
  module *and* your role in it can see that area. A warehouse login does not get a Finance block.
- **Never a fake zero.** If a section could not be read, it says *Unknown* with the reason. If the
  network is down, the widget keeps the last good figures and marks them with a ⚠ and their age.
- **Refresh:** about every 15 minutes (macOS decides the exact moment). *Save & refresh now* in the
  app forces it.

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

- macOS 14 Sonoma or later.
- Xcode 15 or later (free, from the App Store) — to build it once.
- An Apple ID added in Xcode → Settings → Accounts. A free account's *Personal Team* is enough to
  run it on your own Mac; a paid Apple Developer account is only needed to hand a signed copy to
  someone else.
- A platform API key (`kai_…`).

## Install

### 1. Create an API key

In the web app: **Profile → Keys → Generate key**.

- Name it e.g. *Mac widget*.
- Bind it to the workspace you want to watch (recommended — the key can then read nothing else).
- If you restrict endpoints, allow `/functions/v1/workspace-pulse`.
- Copy the key — it is shown **once**.

The key acts as you: the widget sees exactly what you see in the app, never more. The endpoint
is read-only and costs no credits.

### 2. Build and install

```bash
git clone https://github.com/creativeghq/hub-widget.git
cd hub-widget
DEVELOPMENT_TEAM=ABCDE12345 ./scripts/install.sh
```

Your Team ID is in Xcode → Settings → Accounts → select your Apple ID → the *Team* column
(or developer.apple.com → Membership). The script installs XcodeGen if needed, builds a signed
Release copy, puts **Hub Widget.app** in `/Applications` and opens it.

Prefer Xcode? `brew install xcodegen && xcodegen generate && open HubWidget.xcodeproj`, choose
your team under *Signing & Capabilities* for both the **HubWidget** and **HubWidgetExtension**
targets, then **Product → Run**.

### 3. Connect

In the Hub Widget window, paste the key and press **Connect**. You get a preview of exactly what
the widget will show. If you belong to several workspaces, pick one; you can also switch sections
off for the overview widget.

### 4. Add the widget

Right-click the desktop → **Edit Widgets…** (or open Notification Centre → *Edit Widgets*),
search for **Hub**, and drag *Hub overview* or *Hub section* onto the desktop. For *Hub section*,
right-click it → **Edit "Hub section"** to choose the section.

Keep **Hub Widget.app** in `/Applications`: it is what opens links from the widget and holds the
settings. It does not need to stay open.

## How it works

```
 Widget (WidgetKit, sandboxed)          Hub Widget.app (settings)
        │  reads key + settings  ◄── App Group + Keychain ──►  writes them
        │
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
  HubStore.swift            App Group settings and the Keychain key
  Formatting.swift          number/money/date formatting, section icons
  SamplePulse.swift         placeholder data for the widget gallery only
HubWidget/                  the app: settings window, deep-link handler
HubWidgetExtension/         the widgets: timeline providers, views, section picker
Tests/                      decoding/formatting tests against a recorded response
scripts/install.sh          build, sign, install, open
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

### Adding a figure or a section

Figures come from the platform, not from this repo. Add it to `public.get_workspace_pulse` in the
platform database (a `pulse_metric(...)` entry in the right section) and every installed widget
shows it on its next refresh, no new build. A brand-new **section** also needs its key added
to `SectionKind` (for the section picker) and to `SectionStyle.symbol` (its icon).

## Troubleshooting

| You see | Do this |
|---|---|
| "No API key yet" in the widget | Open Hub Widget.app, paste the key, press Connect. |
| "The API key was refused" | The key was revoked or expired — generate a new one in Profile → Keys. |
| "Workspace not found for this key" | The key is bound to another workspace, or you left it. Clear the workspace picker or use a key bound to the right one. |
| "Could not store the key in the Keychain (OSStatus -34018)" | The app was built without a signing team, so it has no App Group. Rebuild with `DEVELOPMENT_TEAM=… ./scripts/install.sh`. |
| A section says *Unknown* | The platform could not read that section; the note says why. Other sections are unaffected. |
| ⚠ next to "Last good …" | The latest refresh failed (offline, VPN, platform down). Figures are from the time shown. |
| Clicking a figure does nothing | Hub Widget.app must be in `/Applications`; open it once so macOS registers its `hubwidget://` links. |
| Widget missing from the gallery | Open the app once after installing, then log out/in if macOS still has not picked it up. |
| A section you expect is missing | The app's settings list it under the sections with the reason: the module is not in the workspace, or your role cannot see it. |

## Security

- The key is stored in the macOS Keychain (data-protection keychain, shared only through this app's
  App Group) and sent only to the platform API over HTTPS.
- Both the app and the widget are sandboxed with outgoing network access only.
- The endpoint is read-only and runs as the key's owner, so database row security applies exactly
  as in the web app. A key bound to a workspace cannot read any other.
- Removing the key: **Remove key** in the app, and revoke it in Profile → Keys.

## License

CC0 1.0 — see [LICENSE](LICENSE).
