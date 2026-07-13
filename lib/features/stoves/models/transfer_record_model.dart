/// A stove transfer record from the `get-transfer-history` edge function.
/// Mirror of the web `TransferRecord`. Defensive parsing.
class TransferRecordModel {
  TransferRecordModel({
    required this.id,
    required this.transactionId,
    required this.partnerName,
    required this.state,
    required this.branch,
    required this.stoveCount,
    required this.source,
    required this.transferDate,
    required this.salesDate,
  });

  final String id;
  final String transactionId;
  final String partnerName;
  final String? state;
  final String? branch;
  final int stoveCount;
  final String source;
  final String? transferDate;
  final String? salesDate;

  factory TransferRecordModel.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    int i(dynamic v) => v is int ? v : int.tryParse(s(v)) ?? 0;
    return TransferRecordModel(
      id: s(json['id']),
      transactionId: s(json['transaction_id']),
      partnerName: s(json['partner_name'] ?? json['partnerName']),
      state: json['state']?.toString(),
      branch: json['branch']?.toString(),
      stoveCount: i(json['stove_count'] ?? json['stoveCount']),
      source: s(json['source']),
      transferDate: json['transfer_date']?.toString(),
      salesDate: json['sales_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transaction_id': transactionId,
        'partner_name': partnerName,
        'state': state,
        'branch': branch,
        'stove_count': stoveCount,
        'source': source,
        'transfer_date': transferDate,
        'sales_date': salesDate,
      };
}
