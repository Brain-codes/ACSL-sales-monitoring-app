import 'dart:convert';

import 'package:crypto/crypto.dart';


/// Phone-number handling for the sales form.
///
/// One job: produce the COMPARISON KEY used for end-user phone uniqueness.
///
/// The key is the last 10 digits, so the same subscriber written any way
/// collapses to one value:
///
///   08031234567     -> 8031234567
///   2348031234567   -> 8031234567
///   +2348031234567  -> 8031234567
///
/// This must match the backend, which compares digits-only tails the same way
/// (`create-sale`, `update-sale`, `get-end-user-phones`). If the two ever
/// disagree, a phone the client thinks is free is rejected at submit — or
/// worse, a duplicate slips in.
///
/// There is deliberately NO format validation here (removed 22 Jul 2026):
/// sellers enter numbers in whatever notation they have, and rejecting a
/// notation blocked real entries. Normalization above means format never
/// affects duplicate detection anyway.
class PhoneUtils {
  const PhoneUtils._();

  /// The uniqueness comparison key — last 10 digits. Returns an empty string
  /// when there aren't enough digits to compare, so callers can skip rather
  /// than match everything on a partial entry.
  static String normalizePhone(String? value) {
    if (value == null) return '';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return '';
    return digits.substring(digits.length - 10);
  }
}

/// The buyer key: one customer on one number, as the server computes it
/// (`supabase/functions/_shared/buyerKey.ts`). Same phone + same key = the
/// same customer, refused; same phone + different key = a family, allowed.
/// Proven against `test/fixtures/buyer-key-vectors.json` — change both or neither.
///
/// [titles] always comes from the server (`buyerKeyRules.titles`), never code.
/// Never store a computed key: compute it when needed with current titles.
class BuyerKey {
  const BuyerKey._();

  static String phoneTail(String? phone) => PhoneUtils.normalizePhone(phone);

  static String nameKey(
    String? first,
    String? surname,
    String? joined,
    List<String> titles,
  ) {
    final parts = [first, surname]
        .map((s) => (s ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    var s = parts.isNotEmpty ? parts.join(' ') : (joined ?? '');
    s = s.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ');
    s = s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => m[0]!.toLowerCase());
    s = s.replaceAll(RegExp(r'[\s,/]+'), ' ');
    s = s.replaceAll(RegExp(r'[^a-z ]'), '');
    final words = s
        .split(' ')
        .where((w) => w.isNotEmpty && !titles.contains(w))
        .toList()
      ..sort();
    return words.join(' ');
  }

  /// Empty when the phone or the name is too short to key: only the
  /// shared-number note can apply then.
  static String compute(
    String? phone,
    String? first,
    String? surname,
    String? joined,
    List<String> titles,
  ) {
    final tail = phoneTail(phone);
    final name = nameKey(first, surname, joined, titles);
    if (tail.isEmpty || name.isEmpty) return '';
    return sha256
        .convert(utf8.encode('$tail|$name'))
        .toString()
        .substring(0, 16);
  }

  /// Key of a queued sale payload (create-sale body shape).
  static String ofPayload(Map<String, dynamic> p, List<String> titles) =>
      compute(
        p['phone']?.toString(),
        p['endUserFirstName']?.toString(),
        p['endUserSurname']?.toString(),
        p['endUserName']?.toString(),
        titles,
      );
}

/// What the sell form's live check found (handover step 4).
enum PhoneCheck { none, shared, sameBuyer }

/// The live check's decision, pure so it can be tested.
///
/// When editing, [originalKey] / [originalTail] are the sale's own values:
/// it never matches itself, and its own number is never "in use".
PhoneCheck classifyPhoneCheck({
  required String tail,
  required String key,
  required Set<String> knownPhones,
  required Set<String> knownKeys,
  String? originalKey,
  String? originalTail,
}) {
  if (tail.isEmpty) return PhoneCheck.none;
  final ownKey = key.isNotEmpty && key == originalKey;
  if (key.isNotEmpty && !ownKey && knownKeys.contains(key)) {
    return PhoneCheck.sameBuyer;
  }
  if (tail == originalTail || ownKey) return PhoneCheck.none;
  return knownPhones.contains(tail) ? PhoneCheck.shared : PhoneCheck.none;
}
