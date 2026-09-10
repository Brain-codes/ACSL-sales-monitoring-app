// To parse this JSON data, do
//
//     final profileModel = profileModelFromJson(jsonString);

import 'dart:convert';

ProfileModel profileModelFromJson(String str) => ProfileModel.fromJson(json.decode(str));

String profileModelToJson(ProfileModel data) => json.encode(data.toJson());

class ProfileModel {
  String id;
  String? email;
  String? username;
  String? fullName;
  String? phone;
  String? role;
  bool? hasChangedPassword;
  DateTime? createdAt;
  OrganizationModel? organization;

  ProfileModel({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    this.phone,
    this.role,
    this.hasChangedPassword,
    this.createdAt,
    this.organization,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json["id"],
        email: json["email"],
        username: json["username"],
        fullName: json["full_name"],
        phone: json["phone"],
        role: json["role"],
        hasChangedPassword: json["has_changed_password"],
        // M12: tryParse, never parse. A malformed timestamp used to throw
        // out of fromJson, which killed the whole profile — and the profile
        // is what isSignedIn depends on, so one bad character logged the
        // user out. A date we cannot read is worth less than the account.
        createdAt: DateTime.tryParse(json["created_at"]?.toString() ?? ""),
        organization: json["organizations"] != null
            ? (json["organizations"] is List && (json["organizations"] as List).isNotEmpty
                ? OrganizationModel.fromJson((json["organizations"] as List).first)
                : json["organizations"] is Map<String, dynamic>
                    ? OrganizationModel.fromJson(json["organizations"])
                    : null)
            : json["organization"] != null
                ? OrganizationModel.fromJson(json["organization"])
                : null,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "email": email,
        "username": username,
        "full_name": fullName,
        "phone": phone,
        "role": role,
        "has_changed_password": hasChangedPassword,
        "created_at": createdAt?.toIso8601String(),
        "organization": organization?.toJson(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────

OrganizationModel organizationModelFromJson(String str) => OrganizationModel.fromJson(json.decode(str));

String organizationModelToJson(OrganizationModel data) => json.encode(data.toJson());

class OrganizationModel {
  String id;
  String partnerName;
  String branch;
  String state;
  String? contactPerson;
  String? contactPhone;
  String? alternativePhone;
  String? email;
  String? address;
  DateTime? createdAt;

  OrganizationModel({
    required this.id,
    required this.partnerName,
    required this.branch,
    required this.state,
    this.contactPerson,
    this.contactPhone,
    this.alternativePhone,
    this.email,
    this.address,
    this.createdAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) => OrganizationModel(
        id: json["id"],
        partnerName: json["partner_name"] ?? json["name"] ?? "Unknown Partner",
        branch: json["branch"] ?? "Main Branch",
        state: json["state"] ?? "Unknown State",
        contactPerson: json["contact_person"],
        contactPhone: json["contact_phone"],
        alternativePhone: json["alternative_phone"],
        email: json["email"] ?? json["partner_email"],
        address: json["address"],
        // M12: tryParse, never parse — as above.
        createdAt: DateTime.tryParse(json["created_at"]?.toString() ?? ""),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "partner_name": partnerName,
        "branch": branch,
        "state": state,
        "contact_person": contactPerson,
        "contact_phone": contactPhone,
        "alternative_phone": alternativePhone,
        "email": email,
        "address": address,
        "created_at": createdAt?.toIso8601String(),
      };

  String get name => partnerName;
  String? get partnerEmail => email;
}
