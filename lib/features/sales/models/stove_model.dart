// To parse this JSON data, do
//
//     final stoveModel = stoveModelFromJson(jsonString);

import 'dart:convert';

StoveModel stoveModelFromJson(String str) => StoveModel.fromJson(json.decode(str));

String stoveModelToJson(StoveModel data) => json.encode(data.toJson());

class StoveModel {
  String stoveId;
  String? serialNo;
  String? status;
  String? organizationId;

  StoveModel({
    required this.stoveId,
    this.serialNo,
    this.status,
    this.organizationId,
  });

  factory StoveModel.fromJson(Map<String, dynamic> json) => StoveModel(
        stoveId: json["stove_id"]?.toString() ?? json["id"]?.toString() ?? "",
        serialNo: json["serial_no"] ?? json["stoveSerialNo"],
        status: json["status"],
        organizationId: json["organization_id"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "stove_id": stoveId,
        "serial_no": serialNo,
        "status": status,
        "organization_id": organizationId,
      };

  String get displayId => (serialNo != null && serialNo!.isNotEmpty) ? serialNo! : stoveId;
}
