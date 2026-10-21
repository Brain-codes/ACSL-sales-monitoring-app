import 'package:flutter_test/flutter_test.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';
import 'package:stove_transaction/features/sales/create/create_sale_controller.dart';

void main() {
  group('error parsing', () {
    test('a 409 keeps errorCode and errorTransactionId', () {
      final r = SupabaseService.errorFromBody(
          '{"success":false,"code":"SAME_BUYER_SAME_PHONE",'
          '"transactionId":"TR-8C94F1","message":"Not saved: this customer"}',
          409);
      expect(r.success, isFalse);
      expect(r.code, 409);
      expect(r.errorCode, 'SAME_BUYER_SAME_PHONE');
      expect(r.errorTransactionId, 'TR-8C94F1');
      expect(r.message, 'Not saved: this customer');
    });

    test('null transactionId and a non-JSON body are safe', () {
      final a = SupabaseService.errorFromBody(
          '{"code":"SAME_BUYER_SAME_PHONE","transactionId":null,"message":"x"}',
          409);
      expect(a.errorTransactionId, isNull);
      final b = SupabaseService.errorFromBody('<html>', 500);
      expect(b.errorCode, isNull);
      expect(b.message, 'Something went wrong. Please try again.');
    });
  });

  group('alreadyCreated', () {
    SupabaseApiResponse err(String msg, int code, [String? ec]) =>
        SupabaseApiResponse.error(msg, code: code, errorCode: ec);

    test('true for the transaction-id duplicate', () {
      expect(
          SyncService.alreadyCreated(
              err('A sale with transaction ID "TR-1" already exists', 409)),
          isTrue);
    });

    test('false for SAME_BUYER_SAME_PHONE, whatever its wording', () {
      expect(
          SyncService.alreadyCreated(err(
              'transaction id TR-1 already exists', 409, 'SAME_BUYER_SAME_PHONE')),
          isFalse);
    });

    test('false for any other 409 and for a 500', () {
      expect(SyncService.alreadyCreated(err('Stove already sold', 409)), isFalse);
      expect(
          SyncService.alreadyCreated(
              err('A sale with transaction ID "TR-1" already exists', 500)),
          isFalse);
    });
  });

  group('shares_phone_with', () {
    test('lists named sales, skips null ids', () {
      expect(
          CreateSaleController.sharedTransactionIds({
            'shares_phone_with': [
              {'sale_id': 'a', 'transaction_id': 'TR-1', 'same_buyer': false},
              {'sale_id': 'b', 'transaction_id': null, 'same_buyer': false},
              {'sale_id': 'c', 'transaction_id': 'TR-3', 'same_buyer': false},
            ]
          }),
          ['TR-1', 'TR-3']);
    });

    test('absent → empty', () {
      expect(CreateSaleController.sharedTransactionIds({'success': true}), isEmpty);
      expect(CreateSaleController.sharedTransactionIds(null), isEmpty);
    });
  });
}
