/// The phone and buyer rule's wording (handover section 6), in one place so
/// every agent reads the same thing. E2 is the server's message, verbatim.
class BuyerRuleMessages {
  const BuyerRuleMessages._();

  /// Server refusal code for "same name and phone". Decide on this, never on
  /// the message text.
  static const sameBuyerCode = 'SAME_BUYER_SAME_PHONE';

  static const n1 =
      'This number is already on another sale. If this is a different person, '
      'a family can share one phone and the sale can be saved.';
  static const n2 =
      'This phone number is already on another sale. Check it is the right '
      'number for this customer, then continue.';
  static const e1 =
      'This customer (same name and phone number) is already registered. '
      'The same customer cannot be recorded twice.';
  static String s1(List<String> txnIds) =>
      'This number is also on sale ${txnIds.join(', ')}.';
  static const r1 =
      'Not saved: this customer is already registered. Tap to see why, or Edit.';
  static const r2 =
      'This customer may already be registered. Check the name and phone '
      'before syncing.';
  static String t1(int n) => '$n not saved (same customer)';
}
