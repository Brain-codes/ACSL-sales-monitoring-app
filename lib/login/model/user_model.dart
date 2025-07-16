// To parse this JSON data, do
//
//     final usermodel = usermodelFromJson(jsonString);

import 'dart:convert';

UserModel usermodelFromJson(String str) => UserModel.fromJson(json.decode(str));

String usermodelToJson(UserModel data) => json.encode(data.toJson());

class UserModel {
  String? instanceId;
  String? id;
  String? aud;
  String? role;
  String? email;
  String? encryptedPassword;
  String? emailConfirmedAt;
  String? invitedAt;
  String? confirmationToken;
  DateTime? confirmationSentAt;
  String? recoveryToken;
  String? recoverySentAt;
  String? emailChangeTokenNew;
  String? emailChange;
  String? emailChangeSentAt;
  String? lastSignInAt;
  RawAppMetaData? rawAppMetaData;
  RawUserMetaData? rawUserMetaData;
  String? isSuperAdmin;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? phone;
  String? phoneConfirmedAt;
  String? phoneChange;
  String? phoneChangeToken;
  String? phoneChangeSentAt;
  String? confirmedAt;
  String? emailChangeTokenCurrent;
  int? emailChangeConfirmStatus;
  String? bannedUntil;
  String? reauthenticationToken;
  String? reauthenticationSentAt;
  bool? isSsoUser;
  String? deletedAt;
  bool? isAnonymous;
  List<String>? providers;

  UserModel({
    this.instanceId,
    this.id,
    this.aud,
    this.role,
    this.email,
    this.encryptedPassword,
    this.emailConfirmedAt,
    this.invitedAt,
    this.confirmationToken,
    this.confirmationSentAt,
    this.recoveryToken,
    this.recoverySentAt,
    this.emailChangeTokenNew,
    this.emailChange,
    this.emailChangeSentAt,
    this.lastSignInAt,
    this.rawAppMetaData,
    this.rawUserMetaData,
    this.isSuperAdmin,
    this.createdAt,
    this.updatedAt,
    this.phone,
    this.phoneConfirmedAt,
    this.phoneChange,
    this.phoneChangeToken,
    this.phoneChangeSentAt,
    this.confirmedAt,
    this.emailChangeTokenCurrent,
    this.emailChangeConfirmStatus,
    this.bannedUntil,
    this.reauthenticationToken,
    this.reauthenticationSentAt,
    this.isSsoUser,
    this.deletedAt,
    this.isAnonymous,
    this.providers,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    instanceId: json["instance_id"],
    id: json["id"],
    aud: json["aud"],
    role: json["role"],
    email: json["email"],
    encryptedPassword: json["encrypted_password"],
    emailConfirmedAt: json["email_confirmed_at"],
    invitedAt: json["invited_at"],
    confirmationToken: json["confirmation_token"],
    confirmationSentAt: json["confirmation_sent_at"] != null ? DateTime.parse(json["confirmation_sent_at"]) : null,
    recoveryToken: json["recovery_token"],
    recoverySentAt: json["recovery_sent_at"],
    emailChangeTokenNew: json["email_change_token_new"],
    emailChange: json["email_change"],
    emailChangeSentAt: json["email_change_sent_at"],
    lastSignInAt: json["last_sign_in_at"],
    rawAppMetaData: json["raw_app_meta_data"] != null ? RawAppMetaData.fromJson(json["raw_app_meta_data"]) : null,
    rawUserMetaData: json["raw_user_meta_data"] != null ? RawUserMetaData.fromJson(json["raw_user_meta_data"]) : null,
    isSuperAdmin: json["is_super_admin"],
    createdAt: json["created_at"] != null ? DateTime.parse(json["created_at"]) : null,
    updatedAt: json["updated_at"] != null ? DateTime.parse(json["updated_at"]) : null,
    phone: json["phone"],
    phoneConfirmedAt: json["phone_confirmed_at"],
    phoneChange: json["phone_change"],
    phoneChangeToken: json["phone_change_token"],
    phoneChangeSentAt: json["phone_change_sent_at"],
    confirmedAt: json["confirmed_at"],
    emailChangeTokenCurrent: json["email_change_token_current"],
    emailChangeConfirmStatus: json["email_change_confirm_status"],
    bannedUntil: json["banned_until"],
    reauthenticationToken: json["reauthentication_token"],
    reauthenticationSentAt: json["reauthentication_sent_at"],
    isSsoUser: json["is_sso_user"],
    deletedAt: json["deleted_at"],
    isAnonymous: json["is_anonymous"],
    providers: json["providers"] != null ? List<String>.from(json["providers"].map((x) => x)) : null,
  );

  Map<String, dynamic> toJson() => {
    "instance_id": instanceId,
    "id": id,
    "aud": aud,
    "role": role,
    "email": email,
    "encrypted_password": encryptedPassword,
    "email_confirmed_at": emailConfirmedAt,
    "invited_at": invitedAt,
    "confirmation_token": confirmationToken,
    "confirmation_sent_at": confirmationSentAt?.toIso8601String(),
    "recovery_token": recoveryToken,
    "recovery_sent_at": recoverySentAt,
    "email_change_token_new": emailChangeTokenNew,
    "email_change": emailChange,
    "email_change_sent_at": emailChangeSentAt,
    "last_sign_in_at": lastSignInAt,
    "raw_app_meta_data": rawAppMetaData?.toJson(),
    "raw_user_meta_data": rawUserMetaData?.toJson(),
    "is_super_admin": isSuperAdmin,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "phone": phone,
    "phone_confirmed_at": phoneConfirmedAt,
    "phone_change": phoneChange,
    "phone_change_token": phoneChangeToken,
    "phone_change_sent_at": phoneChangeSentAt,
    "confirmed_at": confirmedAt,
    "email_change_token_current": emailChangeTokenCurrent,
    "email_change_confirm_status": emailChangeConfirmStatus,
    "banned_until": bannedUntil,
    "reauthentication_token": reauthenticationToken,
    "reauthentication_sent_at": reauthenticationSentAt,
    "is_sso_user": isSsoUser,
    "deleted_at": deletedAt,
    "is_anonymous": isAnonymous,
    "providers": providers != null ? List<dynamic>.from(providers!.map((x) => x)) : null,
  };
}

class RawAppMetaData {
  String? provider;
  List<String>? providers;

  RawAppMetaData({
    this.provider,
    this.providers,
  });

  factory RawAppMetaData.fromJson(Map<String, dynamic> json) => RawAppMetaData(
    provider: json["provider"],
    providers: json["providers"] != null ? List<String>.from(json["providers"].map((x) => x)) : null,
  );

  Map<String, dynamic> toJson() => {
    "provider": provider,
    "providers": providers != null ? List<dynamic>.from(providers!.map((x) => x)) : null,
  };
}

class RawUserMetaData {
  String? sub;
  String? role;
  String? email;
  String? fullName;
  bool? emailVerified;
  bool? phoneVerified;

  RawUserMetaData({
    this.sub,
    this.role,
    this.email,
    this.fullName,
    this.emailVerified,
    this.phoneVerified,
  });

  factory RawUserMetaData.fromJson(Map<String, dynamic> json) => RawUserMetaData(
    sub: json["sub"],
    role: json["role"],
    email: json["email"],
    fullName: json["fullName"],
    emailVerified: json["email_verified"],
    phoneVerified: json["phone_verified"],
  );

  Map<String, dynamic> toJson() => {
    "sub": sub,
    "role": role,
    "email": email,
    "fullName": fullName,
    "email_verified": emailVerified,
    "phone_verified": phoneVerified,
  };
}