// To parse this JSON data, do
//
//     final salesagentmodel = salesagentmodelFromJson(jsonString);

import 'dart:convert';

SalesAgentModel salesagentmodelFromJson(String str) =>
    SalesAgentModel.fromJson(json.decode(str));

String salesagentmodelToJson(SalesAgentModel data) =>
    json.encode(data.toJson());

class SalesAgentModel {
  String? id;
  DateTime? createdAt;
  String? email;
  String? fullName;
  String? phone;
  String? role;
  bool? hasChangedPassword;

  SalesAgentModel({
    this.id,
    this.createdAt,
    this.email,
    this.fullName,
    this.phone,
    this.role,
    this.hasChangedPassword,
  });

  factory SalesAgentModel.fromJson(Map<String, dynamic> json) =>
      SalesAgentModel(
        id: json["id"],
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
        email: json["email"],
        fullName: json["full_name"],
        phone: json["phone"],
        role: json["role"],
        hasChangedPassword: json["has_changed_password"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "created_at": createdAt?.toIso8601String(),
        "email": email,
        "full_name": fullName,
        "phone": phone,
        "role": role,
        "has_changed_password": hasChangedPassword,
      };
}
