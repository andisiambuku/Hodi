# Hodi

Offline-first home-visit app for community health nurses.

*Hodi* is what you call out when you arrive at someone's home; the household
answers *Karibu*.

Hodi is a Flutter app (Android first) that lets a nurse register patients,
plan and record home visits and capture vitals with no signal at all, then
quietly syncs when the phone is back online. When two nurses change the same
record while offline, nothing is lost silently.

## Contents

- [Features](#features)
- [Case study](#case-study)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [Collaborating](#collaborating)
- [Design decisions](#design-decisions)
- [Known gaps](#known-gaps)

## Features

**Patients**
- Register a patient with full name, household head, location, an optional
  phone number and an account status (Active / Inactive).
- Phone numbers are validated (7–15 digits, optional leading `+`).
- Mark a patient active or inactive at any time, offline included. The change
  is queued and synced like any other edit.

**Visits and vitals**
- Today's visit list and a Home screen summarising the day.
- Record a visit, with temperature and blood pressure readings.
- Visit detail, where vitals can be recorded and edited.

**Offline-first sync**
- Everything is written to the phone first, in one transaction together with
  an outbox entry. The app never waits on the network.
- Outbox with coalescing: repeated edits to an unsent record fold into one
  change.
- Idempotent push, pull, retry with backoff, and a sync history.
- A status pill in every header: online, offline or syncing. A Sync hub and a
  Pending changes screen show exactly what is waiting to be sent.

**Conflict handling**
- Field-level resolution using hybrid logical clocks (HLC). Edits to different
  fields of the same record are merged, and the nurse gets a notice.
- Edits to the same field: the newer one wins and the other nurse sees a card
  with the choice to re-enter or keep.
- Clinical safety rule: vitals and account status are never changed or kept
  without a visible card, even when the resolution is automatic.
- Records deleted elsewhere but edited here are kept and flagged for review.

**Security and resilience**
- Local database encrypted with SQLCipher (AES-256). The key lives in the
  platform secure storage.
- Startup never ends on a blank screen: a failed key read offers "Try again"
  and a confirmed reset. Nothing is wiped automatically.

**Languages and accessibility**
- English and Swahili, switchable in Profile. Stored data stays data and is
  translated when shown, so history reads in the nurse's current language.
- Layouts scale to 200% text size without overflow, with screen-reader labels
  and 48dp touch targets.

## Case study

### The problem

Community health nurses do their work in households, often in places where
mobile coverage is weak or absent. Apps that assume a connection fail them in
three ways:

1. **Lost work.** A form that needs the network to save loses the visit when
   the signal drops mid-entry.
2. **Silent overwrites.** Several nurses and clinic tablets work on the same
   patients. With "last write wins", one person's edit, including a vital
   sign, can quietly erase another's.
3. **Unclear state.** Nurses can't tell whether a record reached the server,
   so they re-enter it or stop trusting the app.

### The approach

- **The phone is the source of truth for the nurse.** Every action writes
  locally and succeeds immediately. Syncing is a background concern that can
  fail and retry without the nurse noticing.
- **Say what is saved and what is waiting.** Every record carries a sync
  state, and the whole app uses one count: changes saved on this phone,
  waiting to sync.
- **Resolve conflicts per field, not per record.** Two nurses editing
  different fields of the same patient is not a conflict, so those edits are
  merged. Only a true overlap needs a human, and it is shown in plain
  language.
- **Be stricter with clinical data.** Anything clinical is never overwritten
  or kept without a card telling the nurse.
- **Compare before sending.** The sync order is pull, resolve, then push. An
  unsent local edit can't have been seen by whoever made a remote edit, so it
  must be compared against remote changes before it goes out.

### A worked example: account status

Nurse A marks a patient **inactive** on her phone with no signal. Nurse B,
on a clinic tablet, marks the same patient **active**.

| Step | What happens |
|---|---|
| Both save | Each device updates locally and queues a change stamped with its HLC. |
| A syncs | The pull brings in B's newer change. The fields overlap and B's is newer, so B's value wins. |
| A is told | A card says *"You changed Amina's account status to Inactive. A newer edit from Clinic Tablet 2 set it to Active, so that value was kept."*, with the choice to re-enter hers or keep the newer one. |
| If A's was newer | Her value is kept, and since the field is clinical she still sees a card showing what the other tablet had set. |

The same flow is covered by automated tests in both directions, and you can
try it by hand: mark a patient inactive, open Profile and tap *Simulate
patient status change from Clinic Tablet 2* (debug builds), then sync.

### What it demonstrates

- A real offline-first architecture on mobile: local database, outbox and
  idempotent sync.
- Conflict resolution that is explainable to a non-technical user.
- Healthcare-minded defaults: encryption at rest, no silent loss, no blank
  screens, plain-language copy in two languages.

## Architecture

```
lib/
  app/        app shell, router, theme and design tokens, startup
  core/
    db/       drift schema, SQLCipher setup, key store, migrations, seed data
    sync/     outbox, HLC clock, sync engine, conflict resolver, history
    network/  ApiClient seam, in-memory FakeApiClient
    widgets/  shared UI components
  features/   home, patients, visits, vitals, sync, profile
  l10n/       en and sw strings
```

| Concern | Choice |
|---|---|
| UI and state | Flutter, Riverpod, go_router |
| Local storage | drift on SQLite with SQLCipher |
| Secrets | flutter_secure_storage |
| Connectivity | connectivity_plus |
| Background work | workmanager (plumbing in place, switched off, see below) |
| Server | `ApiClient` interface, with `FakeApiClient` standing in for now |

## Getting started

Requirements: Flutter with Dart `^3.12.2`, and an Android emulator or device.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift code
flutter gen-l10n                                           # translations
flutter run
```

Tests and checks:

```sh
flutter analyze
flutter test                      # goldens included
flutter test --update-goldens     # after intentional visual changes
```

On first launch the app seeds demo patients and visits. The Profile screen has
debug-only buttons that simulate edits from a second tablet, which is the
easiest way to see conflict cards.

## Collaborating

Contributions are welcome: code, translations, clinical or UX review, and
bug reports.

**Ways to help**
- **Swahili review.** The strings in `lib/l10n/app_sw.arb` are best-effort
  and need review by a native speaker or clinical translators.
- **A real API client.** Implement `ApiClient` (for example with `dio`) so the
  app can leave the fake server behind.
- **Device testing** on low-end Android phones, and performance numbers.
- **Accessibility and usability** feedback from people who do this work.
- Anything in [Known gaps](#known-gaps).

**Workflow**
1. Open an issue first for anything bigger than a small fix, so we can agree
   on the approach.
2. Fork the repo, then branch from `master`
   (`feature/patient-search`, `fix/sync-retry`).
3. Make the change, with tests. Database changes need a schema version bump
   and an `if (from < N)` migration step in `app_database.dart`, plus a
   migration test.
4. Run `dart format .`, `flutter analyze` and `flutter test`. All must pass.
5. Open a pull request against `master` describing what changed and why, with
   screenshots for UI changes.

**Ground rules**
- Keep it offline-first: user actions must write locally and never wait on
  the network.
- Clinical fields must never be overwritten silently. If you add one, mark it
  `clinical: true` in `entity_schema.dart`.
- Add strings to both `app_en.arb` and `app_sw.arb`; don't hard-code
  user-facing text.
- Never log or commit patient data or keys. Use the seeded demo data only.
- Match the surrounding code style and keep comments sparse and useful.

**Adding a synced field**
1. Add the column in `core/db/tables/entities.dart` and a migration step.
2. Register it in `core/sync/entity_schema.dart`.
3. Include it in the fake server seed (`fake_server_seed.dart`) and the
   repository's outbox payload.
4. Add a label in `localizedFieldLabel` (`l10n.dart`) and the strings.
5. Run `build_runner`, then add a conflict test in
   `test/core/sync/conflict_resolver_test.dart`.

## Design decisions

<details>
<summary>Open decisions and rationale</summary>

- **Home vs Visits route.** The mockups show Home with the Visits tab active,
  so Home is the top of the Visits branch: `/visits` is Home and
  `/visits/today` is the day's list. `/` redirects to `/visits`.
- **Application ID** is still `com.example.hodi`. The spec says `ke.hodi.app`;
  confirm against the org's ID convention before changing it.
- **One pending number.** Everywhere shows the *change* count (unacked outbox
  entries): "5 changes saved on this phone, waiting to sync".
- **Sync order is pull, resolve, push** (the spec says push, pull). See the
  case study. If the pull fails, nothing is pushed.
- **Empty automatic syncs aren't logged** (a manual "Sync now" always is), so
  history isn't 96 identical rows a day. Flip `logEmptyAutoRuns` to log all.
- **Background sync is off** (`backgroundSyncEnabled` in
  `background_sync.dart`) until a real API client exists. The in-memory fake
  server can't be shared with a background isolate and would mark changes
  "synced" that no server saw.
- **SQLCipher via build hook.** `sqlcipher_flutter_libs` is a no-op since
  0.7.0; SQLCipher is selected with `hooks.user_defines.sqlite3.source` in
  `pubspec.yaml`.
- **Lost-key recovery** moves the unreadable DB aside as `hodi.sqlite.lost-*`.
  Those files can never be opened again; consider deleting them instead.
- **Languages.** `en` and `sw`, chosen in Profile (or the phone's language).
  Sync summaries are structured JSON in `sync_log`, and conflict field names,
  visit types and outbox labels are mapped at display time.
- **Startup never ends in a blank screen.** Nothing is wiped automatically
  (the same error happens briefly after a reboot, before first unlock).
- **Text scale.** The status pill and history chips stop growing at 1.3x
  (their meaning is also in the screen-reader label); everything else scales
  to 200% in both languages without overflow (tested).
- **Account status is treated as clinical** for conflict purposes, so the
  loser of a concurrent change always sees a card.

</details>

## Known gaps

- **Concurrent push window.** If another device pushes between this phone's
  pull and its push, the server's last-writer-wins decides silently, and the
  phone later receives the result as a plain remote edit. For clinical fields
  the real API should reject a write whose base version is stale.
- Verified on an Android emulator (API 37): fresh install, relaunch against
  the encrypted DB, localized Home. Not yet run on a physical low-end phone;
  the performance numbers below come from the host machine.
- 500 queued changes (encrypted file DB, host): roughly 11–29 ms per write,
  under 100 ms to list, about 2.5 s to sync in 25 batches. The Pending list
  builds rows lazily.
- No `dio` client yet; `ApiClient` is the seam (`FakeApiClient` stands in).
- Remote edits to a record the nurse deleted locally are dropped (the delete
  stands).
- Patients can be listed and have their status changed, but there is no
  patient detail or edit screen yet for other fields such as phone number.
- No LICENSE file yet; add one before accepting outside contributions.
