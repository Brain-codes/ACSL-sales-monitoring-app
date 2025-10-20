import 'dart:convert';

/// Profile model with organization data
ProfileModel profileFromJson(String str) =>
    ProfileModel.fromJson(json.decode(str));
String profileToJson(ProfileModel data) => json.encode(data.toJson());

class ProfileModel {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? role;
  final bool? hasChangedPassword;
  final DateTime? createdAt;
  final OrganizationModel? organization;

  ProfileModel({
    required this.id,
    this.email,
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
        fullName: json["full_name"],
        phone: json["phone"],
        role: json["role"],
        hasChangedPassword: json["has_changed_password"],
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
        organization: json["organizations"] != null
            ? (json["organizations"] is List &&
                    (json["organizations"] as List).isNotEmpty
                ? OrganizationModel.fromJson(
                    (json["organizations"] as List).first)
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
        "full_name": fullName,
        "phone": phone,
        "role": role,
        "has_changed_password": hasChangedPassword,
        "created_at": createdAt?.toIso8601String(),
        "organization": organization?.toJson(),
      };

  /// Copy with method for easy updates
  ProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? role,
    bool? hasChangedPassword,
    DateTime? createdAt,
    OrganizationModel? organization,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      hasChangedPassword: hasChangedPassword ?? this.hasChangedPassword,
      createdAt: createdAt ?? this.createdAt,
      organization: organization ?? this.organization,
    );
  }

  @override
  String toString() {
    return 'ProfileModel(id: $id, email: $email, fullName: $fullName, organization: ${organization?.partnerName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Organization model - Updated for 8-field structure
class OrganizationModel {
  final String id;
  final String partnerName; // Required - Partner name
  final String branch; // Required - Branch
  final String state; // Required - State
  final String? contactPerson; // Optional - Contact person
  final String? contactPhone; // Optional - Contact phone number
  final String? alternativePhone; // Optional - Alternative phone number
  final String? email; // Optional - Email
  final String? address; // Optional - Address
  final DateTime? createdAt;

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

  factory OrganizationModel.fromJson(Map<String, dynamic> json) =>
      OrganizationModel(
        id: json["id"],
        partnerName: json["partner_name"] ??
            json["name"] ??
            "Unknown Partner", // Backward compatibility
        branch: json["branch"] ?? "Main Branch",
        state: json["state"] ?? "Unknown State",
        contactPerson: json["contact_person"],
        contactPhone: json["contact_phone"],
        alternativePhone: json["alternative_phone"],
        email: json["email"] ?? json["partner_email"], // Backward compatibility
        address: json["address"],
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
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

  /// Copy with method for easy updates
  OrganizationModel copyWith({
    String? id,
    String? partnerName,
    String? branch,
    String? state,
    String? contactPerson,
    String? contactPhone,
    String? alternativePhone,
    String? email,
    String? address,
    DateTime? createdAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      partnerName: partnerName ?? this.partnerName,
      branch: branch ?? this.branch,
      state: state ?? this.state,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Backward compatibility getters
  String get name => partnerName; // For backward compatibility
  String? get partnerEmail => email; // For backward compatibility

  @override
  String toString() {
    return 'OrganizationModel(id: $id, partnerName: $partnerName, branch: $branch, state: $state)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrganizationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
