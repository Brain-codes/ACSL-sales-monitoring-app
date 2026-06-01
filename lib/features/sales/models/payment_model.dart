import 'dart:convert';

PaymentModel paymentModelFromJson(String str) => PaymentModel.fromJson(json.decode(str));

String paymentModelToJson(PaymentModel data) => json.encode(data.toJson());

class PaymentModel {
  String id;
  String name;
  String? description;
  double fixedPrice;
  int durationMonths;
  double minDownPayment;

  PaymentModel({
    required this.id,
    required this.name,
    this.description,
    required this.fixedPrice,
    required this.durationMonths,
    required this.minDownPayment,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json["id"]?.toString() ?? "",
        name: json["name"]?.toString() ?? "",
        description: json["description"]?.toString(),
        fixedPrice: (json["fixed_price"] as num?)?.toDouble() ?? 0.0,
        durationMonths: (json["duration_months"] as num?)?.toInt() ?? 0,
        minDownPayment: (json["min_down_payment"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "description": description,
        "fixed_price": fixedPrice,
        "duration_months": durationMonths,
        "min_down_payment": minDownPayment,
      };

  double get monthlyPayment => durationMonths > 0 ? fixedPrice / durationMonths : fixedPrice;

  /// Label shown in the payment type dropdown, e.g. "3-Month Plan — ₦50,000 / 3 mo"
  String get dropdownLabel {
    final price = fixedPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$name — ₦$price / $durationMonths mo';
  }
}
