// To parse this JSON data, do
//
//     final uploadfilemodel = uploadfilemodelFromJson(jsonString);

import 'dart:convert';

UploadFileModel uploadfilemodelFromJson(String str) => UploadFileModel.fromJson(json.decode(str));

String uploadfilemodelToJson(UploadFileModel data) => json.encode(data.toJson());

class UploadFileModel {
  String? id;
  String? publicId;
  String? url;
  String? type;
  String? createdBy;
  DateTime? createdAt;

  UploadFileModel({
    this.id,
    this.publicId,
    this.url,
    this.type,
    this.createdBy,
    this.createdAt,
  });

  factory UploadFileModel.fromJson(Map<String, dynamic> json) => UploadFileModel(
    id: json["id"],
    publicId: json["public_id"],
    url: json["url"],
    type: json["type"],
    createdBy: json["created_by"],
    createdAt: json["created_at"] != null ? DateTime.parse(json["created_at"]) : null,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "public_id": publicId,
    "url": url,
    "type": type,
    "created_by": createdBy,
    "created_at": createdAt?.toIso8601String(),
  };
}