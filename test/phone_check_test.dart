import 'package:flutter_test/flutter_test.dart';
import 'package:stove_transaction/core/utils/phone_utils.dart';

void main() {
  const tail = '8031234567';
  const key = 'a98b6aac661bef64';
  const family = 'c6681ebc3ee3a674';

  PhoneCheck check({
    String k = key,
    Set<String> phones = const {tail},
    Set<String> keys = const {key},
    String? origKey,
    String? origTail,
  }) =>
      classifyPhoneCheck(
        tail: tail,
        key: k,
        knownPhones: phones,
        knownKeys: keys,
        originalKey: origKey,
        originalTail: origTail,
      );

  test('known key (cached or pending) → same buyer, blocks', () {
    expect(check(), PhoneCheck.sameBuyer);
  });

  test('only the number known → shared note', () {
    expect(check(k: family), PhoneCheck.shared);
  });

  test('a name too short to key still gets the note', () {
    expect(check(k: ''), PhoneCheck.shared);
  });

  test('neither known → nothing', () {
    expect(check(phones: {}, keys: {}), PhoneCheck.none);
  });

  test('no tail → nothing', () {
    expect(
        classifyPhoneCheck(
            tail: '', key: '', knownPhones: {tail}, knownKeys: {key}),
        PhoneCheck.none);
  });

  group('editing', () {
    test('unchanged phone and name: never matches itself', () {
      expect(check(origKey: key, origTail: tail), PhoneCheck.none);
    });

    test('same number, renamed to a family member: no note (own number)', () {
      expect(check(k: family, origKey: key, origTail: tail), PhoneCheck.none);
    });

    test('renamed to match another sale on this number: refused', () {
      expect(
          check(k: family, keys: {key, family}, origKey: key, origTail: tail),
          PhoneCheck.sameBuyer);
    });
  });
}
