import 'package:flutter_test/flutter_test.dart';
import 'package:stove_transaction/core/utils/phone_utils.dart';

void main() {
  group('normalizePhone', () {
    test('every notation collapses to the same comparison key', () {
      // The whole point: format is irrelevant to duplicate detection, so a
      // customer entered as 0803… and later as +234803… still collides.
      const expected = '8031234567';
      expect(PhoneUtils.normalizePhone('08031234567'), expected);
      expect(PhoneUtils.normalizePhone('2348031234567'), expected);
      expect(PhoneUtils.normalizePhone('+2348031234567'), expected);
      expect(PhoneUtils.normalizePhone('0803 123 4567'), expected);
      expect(PhoneUtils.normalizePhone('0803-123-4567'), expected);
    });

    test('different numbers do not collide', () {
      expect(
        PhoneUtils.normalizePhone('08031234567'),
        isNot(PhoneUtils.normalizePhone('08031234568')),
      );
    });

    test('returns empty when there is too little to compare', () {
      // Guards the live check: a partial entry must not match everything.
      expect(PhoneUtils.normalizePhone('0803'), '');
      expect(PhoneUtils.normalizePhone(''), '');
      expect(PhoneUtils.normalizePhone(null), '');
    });
  });
}
