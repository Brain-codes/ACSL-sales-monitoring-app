// To parse this JSON data, do
//
//     final partnerModel = partnerModelFromJson(jsonString);

import 'dart:convert';

PartnerModel partnerModelFromJson(String str) => PartnerModel.fromJson(json.decode(str));

String partnerModelToJson(PartnerModel data) => json.encode(data.toJson());

class PartnerModel {
  String id;
  String partnerName;
  String branch;
  String state;
  int stovesAllocated;
  int stovesSold;
  String? contactPerson;
  String? contactPhone;
  String? email;
  String? address;

  PartnerModel({
    required this.id,
    required this.partnerName,
    required this.branch,
    required this.state,
    required this.stovesAllocated,
    required this.stovesSold,
    this.contactPerson,
    this.contactPhone,
    this.email,
    this.address,
  });

  /// First present key parsed as int (handles num or numeric string); 0 if none.
  static int _firstInt(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null) {
        if (v is num) return v.toInt();
        final parsed = int.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  factory PartnerModel.fromJson(Map<String, dynamic> json) => PartnerModel(
        id: json["id"]?.toString() ?? "",
        partnerName: json["partner_name"] ?? json["name"] ?? "",
        branch: json["branch"] ?? "",
        state: json["state"] ?? "",
        // Received/allocated: super admin (manage-organizations) -> total_stove_ids;
        // ACSL agents (super-admin-agents/.../organizations) -> total_sales.
        stovesAllocated: _firstInt(json, const [
          'total_stove_ids',
          'total_sales',
          'stoves_allocated',
          'stovesAllocated',
        ]),
        // Sold: super admin -> sold_stove_ids; ACSL agents -> approved_sales.
        stovesSold: _firstInt(json, const [
          'sold_stove_ids',
          'approved_sales',
          'stoves_sold',
          'stovesSold',
        ]),
        contactPerson: json["contact_person"],
        contactPhone: json["contact_phone"],
        email: json["email"],
        address: json["address"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "partner_name": partnerName,
        "branch": branch,
        "state": state,
        "stoves_allocated": stovesAllocated,
        "stoves_sold": stovesSold,
        "contact_person": contactPerson,
        "contact_phone": contactPhone,
        "email": email,
        "address": address,
      };

  String get initials => partnerName.isNotEmpty ? partnerName[0].toUpperCase() : "P";
}
