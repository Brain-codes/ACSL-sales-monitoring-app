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
