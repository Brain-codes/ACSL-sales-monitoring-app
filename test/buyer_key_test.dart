import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stove_transaction/core/utils/phone_utils.dart';

/// The server's own test cases (buyer-key-vectors.json). If one fails, the
/// device and the server disagree on "same customer" — do not edit the file.
void main() {
  final json = jsonDecode(
      File('test/fixtures/buyer-key-vectors.json').readAsStringSync()) as Map;
  final titles = (json['titles'] as List).cast<String>();
  final cases = (json['cases'] as List).cast<Map>();

  test('all 18 vectors are present', () => expect(cases.length, 18));

  for (final (i, c) in cases.indexed) {
    test('vector $i: ${c['firstName']} | ${c['surname']} | ${c['joinedName']} | ${c['phone']}', () {
      expect(BuyerKey.phoneTail(c['phone']), c['phoneTail']);
      expect(BuyerKey.nameKey(c['firstName'], c['surname'], c['joinedName'], titles),
          c['nameKey']);
      expect(
          BuyerKey.compute(
              c['phone'], c['firstName'], c['surname'], c['joinedName'], titles),
          c['buyerKey']);
    });
  }

  test('ofPayload reads the create-sale body fields', () {
    expect(
        BuyerKey.ofPayload({
          'phone': '+2348031234567',
          'endUserFirstName': 'Mrs Aisha',
          'endUserSurname': 'Bello',
          'endUserName': 'ignored when parts are set',
        }, titles),
        'a98b6aac661bef64');
  });

  test('titles come from the server: none before the first fetch', () {
    expect(BuyerKey.nameKey('Mrs Aisha', 'Bello', null, const []),
        'aisha bello mrs');
  });
}
