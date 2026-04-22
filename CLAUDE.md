# Clock In — Project Context & Rules

Context file for Claude (and future humans) working on this repo. Read this before making changes.

## What this app is

A simple iOS SwiftUI app for clocking in and out of work with location tracking and history aggregation.

- **Platform:** iOS 17+, SwiftUI, Swift 5.9
- **Backend:** Supabase (auth + Postgres with RLS)
- **Repo:** https://github.com/divinedavis/Clock-In
- **Local path:** `~/Desktop/Clock-In`
- **Bundle ID:** `com.divinedavis.ClockIn`
- **Apple Developer:** user has a paid Apple Developer Program account (divinejdavis@gmail.com) — app can be signed, archived, and shipped to TestFlight / App Store

## Feature surface

1. **Auth** — Supabase email/password sign up + sign in, session restored on launch
2. **Clock tab** — big circular button, green when clocked in, blue when clocked out; records timestamp + lat/lng on each tap
3. **History tab** — segmented filter (Day / Week / Month / Year), running total for current period, grouped list of past entries with per-group totals
4. **Account tab** — shows email, sign out button
5. **Location** — Core Location "When In Use" only, no geofence (records wherever user taps)

## Repo layout

```
Clock-In/
├── CLAUDE.md                         # this file
├── README.md
├── project.yml                       # xcodegen spec — source of truth for the Xcode project
├── ClockIn.xcodeproj/                # generated — do not hand-edit
├── Secrets.example.swift             # template, committed (outside build target)
├── supabase/
│   └── schema.sql                    # run this in Supabase SQL editor once
└── ClockIn/
    ├── App/        ClockInApp, RootView, MainTabView
    ├── Auth/       AuthViewModel, AuthView, AccountView
    ├── Clock/      ClockView, ClockViewModel, LocationManager
    ├── History/    HistoryView, HistoryViewModel
    ├── Models/     TimeEntry
    ├── Services/   TimeEntryService
    ├── Supabase/   SupabaseManager
    └── Secrets.swift                 # gitignored — fill in for local dev
```

## Working rules — READ THESE

### 1. Push to GitHub after every change

After any edit:
1. Build: `xcodebuild -project ClockIn.xcodeproj -scheme ClockIn -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
2. Only commit if the build succeeds
3. `git add` specific files (never `git add -A` blindly — could catch `Secrets.swift`)
4. Verify `git status` shows no `Secrets.swift` before committing
5. `git push origin main`

Remote is SSH: `git@github.com:divinedavis/Clock-In.git`. HTTPS auth is not configured.

### 2. Versioning — update current version, do NOT bump on archive

**Rule:** after every archive (TestFlight / App Store submission), do *not* create a new marketing version or new build number. Update the *current* version in place.

In practical terms:
- `MARKETING_VERSION` (CFBundleShortVersionString) in `project.yml` stays at whatever it currently is
- `CURRENT_PROJECT_VERSION` (CFBundleVersion) in `project.yml` stays at whatever it currently is
- Do not bump these fields after archiving unless the user explicitly asks

If the user says "new version," *then* bump `MARKETING_VERSION` (e.g., 1.0 → 1.1). Build number only gets bumped on explicit request as well.

### 3. Never commit secrets

`ClockIn/Secrets.swift` is gitignored and holds the Supabase URL + anon key. Never stage it. If `git status` shows it, remove from the index with `git reset ClockIn/Secrets.swift`.

The anon key *is* safe to be in a shipped app (it's designed as a public client credential, protected by RLS) — it's kept out of git only so the repo stays portable and you can rotate it without a code change.

### 4. Regenerate the Xcode project after adding files

`.xcodeproj` is generated from `project.yml` by xcodegen. After adding or moving source files:

```
cd ~/Desktop/Clock-In && xcodegen generate
```

Then rebuild. Do not hand-edit `project.pbxproj`.

### 5. Database changes go through `supabase/schema.sql`

Run new SQL in the Supabase SQL editor and also append to `supabase/schema.sql` so the schema is reproducible.

### 6. Ship a TestFlight build after every change

Run `scripts/ship-to-testflight.sh --auto-notes` after every commit that touches app code. The hourly LaunchAgent has been removed — shipping is now per-change so TestFlight stays in lockstep with `main`.

- `--auto-notes` reads `scripts/.last-shipped-commit` (gitignored) and formats release notes from `git log --pretty=format:"- %s" <last-shipped>..HEAD`.
- Each ship bumps `CURRENT_PROJECT_VERSION` by 1 automatically. `MARKETING_VERSION` only changes when you pass `--marketing X.Y`.
- Requires `scripts/asc-config.env` populated, keychain unlocked (for `codesign`), and xcodegen + Xcode CLI tools installed.
- Ships take 10–25 min end-to-end; Claude runs them in the background and waits for the task notification before starting another.

## Database schema

See `supabase/schema.sql`. One table (`public.time_entries`) with RLS policies restricting rows to `auth.uid() = user_id`.

## Build & run locally

```bash
cd ~/Desktop/Clock-In
xcodegen generate
open ClockIn.xcodeproj
# Xcode → Cmd+R to run on simulator
```

First run:
1. Copy `Secrets.example.swift` to `ClockIn/Secrets.swift` and fill in real values (anon key from Supabase dashboard → Settings → API)
2. Run the SQL in `supabase/schema.sql` in the Supabase SQL editor
3. Build & run

## Known quirks

- SourceKit in Xcode/VS Code may show stale "Cannot find type X in scope" diagnostics right after adding files. These clear after the first successful build that indexes the new files.
- `xcodegen` must be installed (`brew install xcodegen`) for anyone regenerating the project.
