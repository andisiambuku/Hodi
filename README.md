# Hodi

Offline-first home-visit app for community health nurses. *Hodi* is what you
call out when you arrive at someone's home; the household answers *Karibu*.

See the build spec for the full design. Build in milestone order.

## Status

- [x] M1 Scaffold, tokens, theme, 4-tab shell, shared widgets + goldens
- [x] M2 Encrypted local data (SQLCipher, key lifecycle, schema, seed)
- [x] M3 Outbox (transactional writes, coalescing, Record visit, Pending changes)
- [x] M4 Connectivity + status pill
- [x] M5 Sync engine (idempotent push, pull, backoff, history, workmanager plumbing)
- [x] M6 Conflicts (HLC resolver, clinical-safety rule, cards, merge banners)
- [x] M7 Home + Sync hub
- [x] M8 Hardening, i18n (`en` + `sw`)

## Decisions to confirm

- **Home vs Visits route.** The mockups show Home with the Visits tab active,
  so Home is the top of the Visits branch: `/visits` is Home and
  `/visits/today` is the day's list. `/` redirects to `/visits`.
- **Application ID** is still `com.example.hodi`. The spec says `ke.hodi.app`;
  confirm against the org's ID convention before changing it.
- **One pending number.** Home said "3 saved" while Pending changes said "5
  changes" in the mockups. Everywhere now shows the *change* count (unacked
  outbox entries): "5 changes saved on this phone, waiting to sync".
- **Sync order is pull → resolve → push** (the spec says push → pull). A change
  that hasn't been sent can't have been seen by whoever made a remote edit, so
  it must be compared with remote edits *before* it is sent. If the pull fails,
  nothing is pushed.
- **Empty automatic syncs aren't logged** (a manual "Sync now" always is), so
  history isn't 96 identical rows a day. Flip `logEmptyAutoRuns` to log all.
- **Background sync is off** (`backgroundSyncEnabled` in `background_sync.dart`)
  until a real API client exists. The in-memory fake server can't be shared with
  a background isolate and would mark changes "synced" that no server saw.
- **SQLCipher via build hook.** `sqlcipher_flutter_libs` is a no-op since
  0.7.0; SQLCipher is selected with `hooks.user_defines.sqlite3.source` in
  `pubspec.yaml`.
- **Lost-key recovery** moves the unreadable DB aside as `hodi.sqlite.lost-*`.
  Those files can never be opened again; consider deleting them instead.

- **Languages.** `en` and `sw`, chosen in Profile (or the phone's language).
  Stored data is kept as data and translated when shown: sync summaries are
  structured JSON in `sync_log`, and conflict field names, visit types and
  outbox labels are mapped at display time, so history reads in the nurse's
  *current* language. **The Swahili strings are best-effort and need review by
  a native speaker / the programme's clinical translators before release.**
- **Startup never ends in a blank screen.** If the phone's secure storage can't
  produce the DB key, the app shows "Try again" and a confirmed "Reset this
  phone's data". Nothing is wiped automatically (the same error happens
  briefly after a reboot, before first unlock).
- **Text scale.** The status pill and history chips stop growing at 1.3x
  (their meaning is also in the screen-reader label); everything else scales to
  200% in both languages without overflow (tested).

## Known gaps

- **Concurrent push window.** If another device pushes between this phone's
  pull and its push, the server's last-writer-wins decides silently, and the
  phone later receives the result as a plain remote edit. For clinical fields
  the real API should reject a write whose base version is stale.
- Verified on an Android emulator (API 37): fresh install, relaunch against the
  encrypted DB, localized Home. Not yet run on a physical low-end phone; the
  500-change performance numbers below come from the host machine.
- 500 queued changes (encrypted file DB, host): ~13 ms per write, 76 ms to list,
  ~3 s to sync in 25 batches. The Pending list builds rows lazily.
- No `dio` client yet; `ApiClient` is the seam (`FakeApiClient` stands in).
- Remote edits to a record the nurse deleted locally are dropped (the delete
  stands).

## Dev

    flutter test                      # goldens included
    flutter test --update-goldens     # after intentional visual changes
