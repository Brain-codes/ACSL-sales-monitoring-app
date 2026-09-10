# Parity Brief Checklist (File 1 — sales-mobile-parity-brief-2026-09-03.pdf)

Source: `mobile-app-core-update/sales-mobile-parity-brief-2026-09-03.pdf`.
20 items ACSL says only the mobile app can fix. Groups, in their priority order:
broken today (M1-M7), truncated (M8-M10), hygiene (M11-M15), platform (M16-M20).

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[!]` blocked

> **Testing on live data.** Production holds real sales. Items marked SAFE below
> are read-only and can be tested freely. Items marked WRITES change records —
> test those with a throwaway sale you are willing to leave behind.

## Facts that drive most of this

Every edge function caps ONE response: sales 500, stoves 500, transfers 200,
organizations 100, agents 100, users 100. Production already has 2,145 sales and
22,032 stoves. So any screen that fetches once and then sums or pages **on the
phone** is wrong or short today. Totals come from the server
(`get-sales-advanced` with `withSummary: true`); rows page with
`pagination.total`. Never sum rows to get a total.

---

## Blocker (not in the brief — found while testing)

- [x] **A1. Every role was bounced to /unauthorized after login.** SAFE
      Permissions resolved ONCE on the splash screen, before anyone had signed
      in, so the role read as null and stayed null. Super admin included.
      Fixed with a revision ticker on `SessionManager` that Riverpod watches.

## Also found while testing

- [ ] **A2. The "New Sale" button covers the pagination control.** SAFE
      The floating button sits over the bottom of the sales list, so the paging
      control underneath it cannot be reached. Folded in with M9.

## Broken or wrong today

- [x] **M1. Stove Management is broken for every role.** SAFE
      `get-stove-ids` is called with an empty body; the server answers 400
      "Missing organization_id". Send `format: format2` (or an organisation id)
      and page with an offset loop. The offline sync already does this correctly
      in `data_refresh_service.dart` — reuse it.
- [x] **M2. The Agreement PDF is built from stale list data.** SAFE
      `get-sale` is called as POST; the function is GET-only and reads `?id=`.
      It fails every time and the failure is swallowed, so the PDF quietly uses
      whatever the list row held. Call it as GET with `queryParams: {id}`.
- [x] **M3. Every sale shows a green "Completed" badge.** SAFE
      Including unpaid instalments and underpaid cash sales. Derive the badge
      from `payment_status` and `total_paid` against `amount`. `total_paid` is
      what was actually collected and is never substituted with `amount`.
- [x] **M4. `fully_paid` has no label and prints raw.** SAFE
- [x] **M5. Financial Reports prints `sales.status` raw.** SAFE
      Shows "Incomplete" for every live sale. That field is *form completeness*,
      not payment. Group by `payment_status`, or relabel it honestly.
- [x] **M6. A part payment on a cash sale is recorded as paid in full.** WRITES
      The form accepts a receipt with no payment model, and the server's outright
      path then sets `total_paid` to the full amount. Refuse on the field: no
      payment model is only allowed when amount received equals the amount.
- [x] **M7. Balance is shown only for instalment sales.** SAFE
      An underpaid cash sale never shows what is owed. Show the balance whenever
      `total_paid < amount`, whatever the type.

## Truncated on the phone

- [ ] **M8. Financial Reports totals and dashboard drill-downs are summed on the
      phone from one 500-row fetch.** SAFE — wrong today.
      Take totals from `get-sales-advanced` with `withSummary: true`.
- [ ] **M9. The sales list fetches once and pages on the phone.** SAFE
      100 rows (500 for a custom range), then paged locally in 25s. Nothing past
      the first fetch is reachable and "a to b of N" reports the fetched count,
      not the real one. Server offset paging; total from `pagination.total`.
- [ ] **M10. Transfer history capped at 50, agents 25, users 25, partner stove
      sheet 500; `has_more` ignored.** SAFE
      The partner list already pages correctly — copy it.

## Correctness hygiene

- [ ] **M11. No timezone is pinned anywhere.** SAFE
      Every date and the "Today" filter use the handset's zone, so a sale made
      late in the evening lands on the wrong day. One helper pinned to
      Africa/Lagos, used everywhere including filter boundaries.
- [ ] **M12. Profile parsing uses bare `DateTime.parse`.** SAFE
      One malformed value throws and kills the profile. Use `tryParse`.
- [ ] **M13. A failed photo upload during offline sync is silent.** WRITES
      The sale syncs without its photo and nobody is told.
- [ ] **M14. Queued unsynced sales can vanish on a decode error.** WRITES
      A bare `catch` swallows it. Never a bare catch around unsynced work.
- [ ] **M15. A failed profile refresh is invisible.** SAFE

## Platform

- [ ] **M16. App version is a hardcoded constant.** SAFE
      Read it from `package_info_plus`.
- [ ] **M17. The update check bypasses `callEdgeFunction`.** SAFE
      Uses a raw HTTP GET. Route it through the normal client.
- [ ] **M18. User management is granted to the wrong roles.** SAFE
      The phone grants it to agent managers and partners; the web grants it to
      super admins only. Match the web — the two files are one rule from now on.
- [ ] **M19. Stale references in the permissions file and CLAUDE.md.** SAFE
- [ ] **M20. The last direct table read is dead code.** SAFE
      Delete it so "edge functions only" can be proven by search.

## Verification

- [ ] **V1. `flutter analyze` clean.**
- [ ] **V2. No `Supabase.from(` anywhere in `lib/`.**
- [ ] **V3. Update `docs/memory.md`.**
- [ ] **V4. On-device testing — yours.**
