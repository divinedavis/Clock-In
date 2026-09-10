# Clock In — raw marketing screenshots

Captured on simulator UDID 977038E4-18DF-4754-8A20-D331FF3BF2C5 (iPhone 17 Pro Max),
all files exactly 1320x2868. Status bar overridden to 9:41 / full battery / full signal.
App was run with a DEBUG-only `-screenshotMode` launch argument (see bottom of this file
for exactly what that changed) — no real Supabase account was created or used.

- `01-clocked-in-timer.png` — Clock tab, actively clocked in (analog clock face, big
  digital elapsed-style readout, "Clocked in since 2:08 PM", "CLOCKED IN" status,
  location captured). — headline: "Clock in instantly"
- `02-todays-shifts.png` — Jobs tab, upcoming assigned shifts with site name, date/time,
  address, and job notes (OSHA 30 reminder, freight elevator instructions). — headline:
  "See your next shift"
- `03-weekly-totals.png` — History tab, Week filter selected: big "Total this week"
  readout (24:15:00) plus the individual clock-in/out entries that make it up. —
  headline: "Track your hours"
- `04-history.png` — History tab, Month filter selected: full multi-week shift history
  grouped by month with per-day durations, running month total (57:15:00) and prior
  month's total visible. — headline: "See your full history"
- `05-account-settings.png` — Account tab: email, clock-in history link, credential
  upload sections (OSHA 30 / Flagger Card), forms link, sign out. — headline: "Manage
  your account"

## Known cosmetic issue (not introduced by this capture)

`simctl ui <udid> appearance light` was applied and verified (`AppleInterfaceStyle`
absent = light), and it held for the two History screens (rendered light, as shown).
But any screen reached through `MainTabView` (Jobs, Account) rendered in dark
regardless — reproduced twice. The Clock tab is intentionally forced dark in code
(`ClockView.swift` has `.preferredColorScheme(.dark)`), so that one is expected. The
Jobs/Account dark rendering looks like a real TabView-related rendering quirk on this
iOS 26.5 simulator build, not something the `-screenshotMode` argument changed — worth
a look if a consistent light-mode screenshot set matters, but out of scope for this
capture pass.

## What was changed to make this possible (all uncommitted, all DEBUG-only)

The app requires a real Supabase sign-in and has no demo mode or documented test
account (checked CLAUDE.md, scripts/, and keychain via `security find-generic-password`
— nothing found). Per instructions, added a minimal DEBUG-only screenshot path instead
of creating a real account:

- `ClockIn/Auth/AuthViewModel.swift` — `startObservingAuth()` now short-circuits to a
  fake signed-in state when launched with `-screenshotMode`; added a `ScreenshotMode`
  enum (DEBUG-only) that reads `-screenshotMode` / `-screenshotScreen <name>` from
  `ProcessInfo.processInfo.arguments`.
- `ClockIn/App/RootView.swift` — when signed in and `-screenshotScreen` is
  `historyWeek` or `historyMonth`, shows `HistoryView(initialRange:)` directly instead
  of `MainTabView()`.
- `ClockIn/App/MainTabView.swift` — added a `selection` state; in DEBUG, reads
  `-screenshotScreen jobs` / `account` to pick the initial tab.
- `ClockIn/Clock/ClockViewModel.swift` — `loadOpenEntry()` seeds a fake in-progress
  `TimeEntry` (clocked in ~3h42m ago) instead of hitting the network, when
  `-screenshotMode` is set.
- `ClockIn/Clock/ClockView.swift` — in `-screenshotMode`, skips the real Core Location
  permission request and instead sets `LocationManager.authorization` /
  `.lastLocation` directly, so the OS location-permission alert never appears.
- `ClockIn/History/HistoryViewModel.swift` — `load()` seeds ~5 weeks of realistic
  weekday shifts (7:00–7:20 AM starts, 7.75–9h durations) instead of calling
  `TimeEntryService`, when `-screenshotMode` is set.
- `ClockIn/History/HistoryView.swift` — added `init(initialRange:)` so the range picker
  can start on Week or Month.
- `ClockIn/Jobs/JobsViewModel.swift` — `load()` seeds 3 realistic construction jobs
  instead of calling `JobService`, when `-screenshotMode` is set.
- `ClockIn/Services/CredentialsService.swift` — `myCredentials(kind:)` returns `[]`
  immediately in `-screenshotMode` so the Account screen doesn't show a network error.

None of this touches Release builds (`#if DEBUG`), and none of it was committed —
`git status` will show these files modified alongside the two pre-existing unrelated
changes (`project.yml` / `ClockIn.xcodeproj/project.pbxproj`, `CURRENT_PROJECT_VERSION`
1→6) that were left untouched.
