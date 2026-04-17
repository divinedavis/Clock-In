# Clock-In

iOS SwiftUI app that lets construction workers (or anyone) clock in and out from their phone, recording location and time, with a history view aggregated by day / week / month / year.

## Stack

- **iOS 17+ / SwiftUI / Swift 5.9**
- **Supabase** — auth (email/password) + Postgres with row-level security
- **Core Location** — "When In Use" permission, records lat/lng on each clock in/out
- **xcodegen** — `.xcodeproj` is generated from `project.yml`

## Quick start

```bash
# install xcodegen if you don't have it
brew install xcodegen

# clone + set up secrets
git clone git@github.com:divinedavis/Clock-In.git
cd Clock-In
cp Secrets.example.swift ClockIn/Secrets.swift
# edit ClockIn/Secrets.swift with your Supabase URL + anon key

# run the DB migration (Supabase dashboard → SQL editor → paste supabase/schema.sql)

# generate the Xcode project and open it
xcodegen generate
open ClockIn.xcodeproj
```

Press Cmd+R in Xcode to run on the simulator.

## Repo map

```
ClockIn/
  App/        ClockInApp, RootView, MainTabView
  Auth/       AuthViewModel, AuthView, AccountView
  Clock/      ClockView, ClockViewModel, LocationManager
  History/    HistoryView, HistoryViewModel
  Models/     TimeEntry
  Services/   TimeEntryService
  Supabase/   SupabaseManager
  Secrets.swift    (gitignored — fill in locally)
supabase/schema.sql
project.yml        (xcodegen spec)
CLAUDE.md          (context + working rules)
```

See [CLAUDE.md](./CLAUDE.md) for the full working rules (push-after-every-change workflow, versioning policy, etc.).
