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

### 3. Create an API key

In the web app: **Profile → Keys → Generate key** (the Hub Widget window has a button for it).

- Name it e.g. *Mac widget*.
- Bind it to the workspace you want to watch (recommended — the key can then read nothing else).
- If you restrict endpoints, allow `/functions/v1/workspace-pulse`.
- Copy the key — it is shown **once**.

The key acts as you: the widget sees exactly what you see in the app, never more. The endpoint
is read-only and costs no credits. Optional: paste it into the Hub Widget window → **Check** to
preview exactly what the widget will show.

### 4. Add the widget and paste the key

1. Right-click the desktop → **Edit Widgets…** (or Notification Centre → *Edit Widgets*).
2. Search **Hub**, drag *Hub overview* or *Hub section* onto the desktop.
3. Right-click the widget → **Edit "Hub overview"** → paste the key into **API key**.
   *Workspace* is optional (empty = the key's workspace). For *Hub section*, pick the **Section**.

You paste the key once: every further Hub widget reuses the last key that worked.

Keep **Hub Widget.app** in `/Applications` — clicking a figure in the widget opens the page in
your browser through it. It does not need to stay open.

### Updating

Download the new release and replace the app (or re-run `scripts/install.sh`). Widgets on the
desktop keep their settings.

## How it works

```
 Widget (WidgetKit, sandboxed)          Hub Widget.app
        │  key + workspace from "Edit Widget"     setup guide, key check,
        │                                         opens clicked links in the browser
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

## Troubleshooting

| You see | Do this |
|---|---|
| "Right-click this widget → Edit Widget…" | No key yet: right-click → Edit, paste the key into API key. |
| "The API key was refused" | The key was revoked or expired — generate a new one in Profile → Keys. |
| "Workspace not found for this key" | The key is bound to another workspace, or you left it. Clear *Workspace* in Edit Widget, or use a key bound to the right one. |
| "Hub Widget can't be opened" / "Apple could not verify…" | First launch of an ad-hoc build — see Install step 2. |
| A section says *Unknown* | The platform could not read that section; the note says why. Other sections are unaffected. |
| ⚠ next to "Last good …" | The latest refresh failed (offline, VPN, platform down). Figures are from the time shown. |
| Clicking a figure does nothing | Hub Widget.app must be in `/Applications`; open it once so macOS registers its `hubwidget://` links. |
| Widget missing from the gallery | Open the app once after installing, then log out/in if macOS still has not picked it up. |
| A section you expect is missing | Check the key in the Hub Widget window: the preview lists hidden sections with the reason (module not in the workspace, or your role cannot see it). |

## Security

- The key lives in the widget's own configuration (set in *Edit Widget*, kept by macOS for that
  widget) and in the widget extension's sandboxed preferences so other Hub widgets can reuse it.
  It is sent only to the platform API over HTTPS. The Hub Widget window does not store it.
- Both the app and the widget are sandboxed with outgoing network access only.
- The endpoint is read-only and runs as the key's owner, so database row security applies exactly
  as in the web app. A key bound to a workspace cannot read any other.
- To revoke: delete the widget and revoke the key in Profile → Keys.
- Builds are signed ad-hoc (no Apple Developer account). Each release lists SHA-256 checksums
  (`SHA256SUMS.txt`); compare with `shasum -a 256 HubWidget-*.dmg`.

## Releasing a new version

Push a tag — `git tag v1.0.1 && git push origin v1.0.1` — or run **Actions → Release → Run
workflow** with a version. The workflow tests, builds a universal (Apple silicon + Intel) app,
packages `HubWidget-<version>.dmg` and `.zip` with checksums, and publishes the GitHub Release.

## License

CC0 1.0 — see [LICENSE](LICENSE).
