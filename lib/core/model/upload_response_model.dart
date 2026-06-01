// To parse this JSON data, do
//
//     final uploadResponse = uploadResponseFromJson(jsonString);

import 'dart:convert';

UploadResponse uploadResponseFromJson(String str) => UploadResponse.fromJson(json.decode(str));

String uploadResponseToJson(UploadResponse data) => json.encode(data.toJson());

class UploadResponse {
  String id;
  String? url;
  String? type;
  String? fileName;

  UploadResponse({
    required this.id,
    this.url,
    this.type,
    this.fileName,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) => UploadResponse(
        id: json["id"]?.toString() ?? "",
        url: json["url"],
        type: json["type"],
        fileName: json["file_name"] ?? json["fileName"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "url": url,
        "type": type,
        "file_name": fileName,
      };
}
