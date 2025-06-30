// To parse this JSON data, do
//
//     final sale = saleFromJson(jsonString);

import 'dart:convert';

Sale saleFromJson(String str) => Sale.fromJson(json.decode(str));

String saleToJson(Sale data) => json.encode(data.toJson());

class Sale {
  final String id;
  final String product;
  final double amount;
  final DateTime date;
  String status;
  String? agentName;
  final String userId;

  Sale({
    required this.id,
    required this.product,
    required this.amount,
    required this.date,
    required this.status,
    this.agentName,
    required this.userId,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json["id"],
        product: json["product"],
        amount: json["amount"],
        date: DateTime.parse(json["date"]),
        status: json["status"],
        agentName: json["agentName"],
        userId: json["userId"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product": product,
        "amount": amount,
        "date": date.toIso8601String(),
        "status": status,
        "agentName": agentName,
        "userId": userId,
      };
}
