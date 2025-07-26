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
    return 'ProfileModel(id: $id, email: $email, fullName: $fullName, organization: ${organization?.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Organization model
class OrganizationModel {
  final String id;
  final String name;
  final String? partnerEmail;
  final DateTime? createdAt;

  OrganizationModel({
    required this.id,
    required this.name,
    this.partnerEmail,
    this.createdAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) =>
      OrganizationModel(
        id: json["id"],
        name: json["name"],
        partnerEmail: json["partner_email"],
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "partner_email": partnerEmail,
        "created_at": createdAt?.toIso8601String(),
      };

  /// Copy with method for easy updates
  OrganizationModel copyWith({
    String? id,
    String? name,
    String? partnerEmail,
    DateTime? createdAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'OrganizationModel(id: $id, name: $name, partnerEmail: $partnerEmail)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrganizationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
