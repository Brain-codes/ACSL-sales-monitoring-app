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

  factory PartnerModel.fromJson(Map<String, dynamic> json) => PartnerModel(
        id: json["id"]?.toString() ?? "",
        partnerName: json["partner_name"] ?? json["name"] ?? "",
        branch: json["branch"] ?? "",
        state: json["state"] ?? "",
        stovesAllocated: json["stoves_allocated"] != null
            ? (json["stoves_allocated"] as num).toInt()
            : json["stovesAllocated"] != null
                ? (json["stovesAllocated"] as num).toInt()
                : 0,
        stovesSold: json["stoves_sold"] != null
            ? (json["stoves_sold"] as num).toInt()
            : json["stovesSold"] != null
                ? (json["stovesSold"] as num).toInt()
                : 0,
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
