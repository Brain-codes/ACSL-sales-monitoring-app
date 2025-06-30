// To parse this JSON data, do
//
//     final sale = saleFromJson(jsonString);

import 'dart:convert';

Sale saleFromJson(String str) => Sale.fromJson(json.decode(str));

String saleToJson(Sale data) => json.encode(data.toJson());

class Sale {
  String id;
  String product;
  double amount;
  DateTime date;

  Sale({
    required this.id,
    required this.product,
    required this.amount,
    required this.date,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json["id"],
        product: json["product"],
        amount: json["amount"],
        date: DateTime.parse(json["date"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product": product,
        "amount": amount,
        "date": date.toIso8601String(),
      };
}
