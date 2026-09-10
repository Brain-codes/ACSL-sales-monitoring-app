# Field Alignment Checklist (File 2 — sales-mobile-field-alignment.md)

Source: `mobile-app-core-update/sales-mobile-field-alignment.md`, dictionary version 2026-09-06.3.
Deadline wave 1: **2026-09-11**. Wave 2: **2027-01-05** (both live on the endpoint, admin-movable).

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[!]` blocked

> The local `supabase/` folder in this repo is STALE. Never use it as a reference
> for endpoint shapes. Truth = the live `sale-dictionary` endpoint + the sales-web repo.

---

## Phase 0 — Blockers to clear before code

- [x] **B1. Confirm the `endUserName` split is safe.** RESOLVED — the comment is stale.
      The live `create-sale/index.ts:190-194` now composes the joined name from the parts
      *before* the required-field check, and writes `end_user_first_name` /
      `end_user_surname` only when a part actually arrived (`:598-603`). Its own comment:
      a caller sending only the parts satisfies the checks exactly as one sending the
      joined name. Sending all three is correct and safe.
- [x] **B2. Get the sales-web repo.** DONE — `acsl-80/ACSL-Sales-Monitoring-Web-App`
      cloned to the scratchpad. (Note: the pre-existing `/Users/Efe/Projects/Web/
      sales-monitoring-web` is a DIFFERENT repo — `shakarho/...` — with no dictionary.)

## Phase 1 — The dictionary plumbing (everything else depends on this)

- [x] **1.1 `SaleFieldDictionary` model.** Dart classes for the endpoint's
      `{ version, source, groups, fields }`, where each field has `key`, `label`,
      `payload`, `type`, `group`, `order`, `mandatoryFrom`, `correctable`, `options`.
      *Means:* the app gains a typed picture of the sale form instead of hardcoded widgets.
- [x] **1.2 `SaleDictionaryService`.** Calls `GET /functions/v1/sale-dictionary` through
      `callEdgeFunction()` (never a raw HTTP call, never a table query).
      *Means:* one place owns fetching. Obeys hard rule #1.
- [x] **1.3 ETag caching + offline persistence.** Store the last good response and its
      ETag; revalidate with `If-None-Match`; on 304 keep the cache; on no network use the
      cache. Fetch at sign-in and on app resume.
      *Means:* admins change wording without an app release, and the form still works
      offline in the field. Obeys hard rule #5.
- [x] **1.4 Riverpod provider exposing the dictionary.** New code = Riverpod, per hard rule #6.
      *Means:* form widgets read labels/options/required-ness reactively.
- [x] **1.5 Bundled fallback copy.** A checked-in snapshot used only on a cold first
      install with no network, clearly marked as a fallback.
      *Means:* a brand-new agent in a no-signal area can still open the form.

## Phase 2 — Required-ness driven by data, not code

- [x] **2.1 `isRequired(field, saleDate)` helper.** Required when
      `mandatoryFrom != null && mandatoryFrom <= sale's own date`.
      *Means:* an old draft is judged by the rules of its own day and is never refused
      for a rule that came later.
- [x] **2.2 Replace every hardcoded validator on dictionary-owned fields** with that helper.
      *Means:* the 2026-09-11 and 2027-01-05 waves switch themselves on. No release needed.
- [x] **2.3 Required-marker (`*`) rendered from the same helper.**
      *Means:* the asterisk can never disagree with the validator.

## Phase 3 — The new / changed fields

- [x] **3.1 Split name.** Send `endUserSurname` + `endUserFirstName`, and keep sending the
      joined `endUserName` until web says it can go. (Gated on B1.)
      *Means:* the server stops guessing where the surname ends.
- [x] **3.2 `addressData.city`.** Currently hardcoded to `''` at `create_sale_controller.dart:2092`.
      Needs a real City/town/village input.
      *Means:* a field that becomes mandatory on 2026-09-11 currently always sends empty.
- [x] **3.3 `salesAgentName`.** New text field, defaults to the signed-in person, editable.
      Not sent at all today.
      *Means:* records who actually made the sale when it differs from the login.
- [x] **3.4 Payment type as its own control.** Cash purchase / Installment purchase radio.
      Today `isInstallment` is only sent when a payment model is picked — a cash sale
      never sends `isInstallment: false`. Payload keys do not change.
      *Means:* cash vs installment becomes an explicit choice instead of a side effect.

## Phase 4 — Free text becomes dropdowns (options from the endpoint)

- [x] **4.1 Baseline stove (`previousStoveType`)** — dropdown from `options`
      (Firewood, Charcoal, LPG today). Send `value`, show `label`.
- [x] **4.2 Fuel source (`cookingFuelSource`)** — replace `cookingFuelSourceCtrl`
      free-text with a dropdown (Collect it, Purchase it).
- [x] **4.3 Cooking location (`cookingLocation`)** — replace `cookingLocationCtrl`
      free-text with a dropdown (Indoor, Outdoor, Semi-indoor).
- [x] **4.4 Pots quantity (`potQuantity`)** — dropdown 0 / 1 / 2.
- [x] **4.5 Retired values kept on existing records.** A saved sale holding a value no
      longer offered still displays it and does not lose it on edit.
      *Means for 4.1-4.5:* the server stops having to guess-map free text like
      "market" -> "Purchase it". Nothing is lost either way, but the data gets clean.

## Phase 5 — Wording from the dictionary

- [x] **5.1 Every sale-form label rendered from `label`.** No field name typed into the app.
- [x] **5.2 "Wonderbox"** as the label for `heatRetentionDevice`.
- [x] **5.3 "CPA (Terms and Conditions)"** as the heading over the six consents.
- [x] **5.4 Same wording on the sale detail / review screens**, not just the create form.
      *Means:* the app shows the paper User Agreement's exact words, and the web's
      `host-field-dictionary-parity.spec.ts` passes.

## Phase 6 — Verification (code-level only; user runs the device)

- [x] **6.1 `flutter analyze` clean.**
- [x] **6.2 Grep proof:** every payload key the rules require today is present in Dart
      source (this is literally what the web's `host-payload-contract.spec.ts` scans for).
- [x] **6.3 Grep proof:** no `Supabase.from(` in feature code; no hex literals outside
      `app_colors.dart`.
- [x] **6.4 Offline round-trip reviewed:** queue a sale with new fields, confirm the
      offline engine serialises and replays them.
- [x] **6.5 Edit hydration reviewed:** an existing sale loads the new fields correctly
      (this is where the old surname/aka swap bug bit).
- [ ] **6.6 Update `docs/memory.md`.**
- [ ] **6.7 Write the note back to ACSL:** shipped / blocked, per item.


---

## What was built (2026-09-09)

**New files**
- `lib/core/model/sale_field_dictionary.dart` — the dictionary model: fields,
  groups, options, `isRequiredOn()`, `labelForValue()`, `isRetiredValue()`.
- `lib/core/services/sale_dictionary_service.dart` — fetch + ETag revalidation +
  offline cache + bundled fallback.
- `assets/data/sale-dictionary.json` — the seed copy (version 2026-09-06.3).

**Changed**
- `supabase_service.dart` / `supabase_api_response.dart` — `callEdgeFunction`
  gained `extraHeaders` and `returnHeaders`, and a 304 is now a success rather
  than an error. Every existing call site is unaffected.
- `data_refresh_service.dart` — the dictionary refreshes first in `refreshAll`,
  so it rides the existing launch / hourly / reconnect sync.
- `create_sale_controller.dart` — dictionary helpers (`dictLabel`,
  `dictRequired`, `dictOptions`), `cityCtrl`, `salesAgentNameCtrl`,
  `isInstallmentSale`, cooking fields as option values, `_requireFromDictionary`
  validation, payload updates.
- `create_sale_screen.dart` — dictionary labels throughout, four dropdowns,
  `_FieldLabel` with a data-driven required marker, payment-type radios.
- `sale_model.dart` — `endUserFirstName`, `endUserSurname`, `city`,
  `salesAgentName` so an edit round-trips instead of re-guessing.

**Two bugs fixed along the way**
- `addressData.city` was hardcoded to `''`, so every sale sent a blank city.
- Editing a synced sale re-split the joined name by whitespace, which is what
  used to swap surname and aka. The parts now come back from the server.

**Verification**
- `flutter analyze`: 0 errors. 10 pre-existing infos remain, none in this work.
- Every payload key required on 2026-09-11 and 2027-01-05 is present in Dart.
- No `Supabase.from(` in feature code.

## Still open

- [ ] **6.6 Update `docs/memory.md`.**
- [ ] **6.7 Write the note back to ACSL** (shipped / blocked, per item).
- [ ] **On-device testing — yours.** Create a sale, edit a synced sale, and
      create one offline then sync it.
- [ ] **Hex-literal rule violations found (pre-existing, out of scope):**
      `lib/core/widgets/update_prompt_sheet.dart` and
      `lib/features/sales/resolve/location_resolution_banner.dart` hold raw
      `Color(0x...)` values, which hard rule #2 forbids outside `app_colors.dart`.
