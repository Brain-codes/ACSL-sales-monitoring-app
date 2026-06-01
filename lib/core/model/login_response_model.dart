// To parse this JSON data, do
//
//     final loginResponse = loginResponseFromJson(jsonString);

import 'dart:convert';

import 'package:stove_transaction/core/model/profile_model.dart';

LoginResponse loginResponseFromJson(String str) => LoginResponse.fromJson(json.decode(str));

String loginResponseToJson(LoginResponse data) => json.encode(data.toJson());

class LoginResponse {
  String accessToken;
  String refreshToken;
  int expiresIn;
  String userId;
  ProfileModel profile;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.userId,
    required this.profile,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final session = json["session"] != null
        ? Map<String, dynamic>.from(json["session"] as Map)
        : <String, dynamic>{};
    final user = session["user"] != null
        ? Map<String, dynamic>.from(session["user"] as Map)
        : <String, dynamic>{};
    // Edge function returns custom profile data under "profile" or "user";
    // fall back to raw session user only as a last resort.
    final profileJson = json["profile"] != null
        ? Map<String, dynamic>.from(json["profile"] as Map)
        : json["user"] != null
            ? Map<String, dynamic>.from(json["user"] as Map)
            : user;

    return LoginResponse(
      accessToken: session["access_token"] ?? "",
      refreshToken: session["refresh_token"] ?? "",
      expiresIn: session["expires_in"] != null ? (session["expires_in"] as num).toInt() : 3600,
      userId: user["id"] ?? profileJson["id"] ?? "",
      profile: ProfileModel.fromJson(profileJson),
    );
  }

  Map<String, dynamic> toJson() => {
        "session": {
          "access_token": accessToken,
          "refresh_token": refreshToken,
          "expires_in": expiresIn,
        },
        "user_id": userId,
        "profile": profile.toJson(),
      };
}
