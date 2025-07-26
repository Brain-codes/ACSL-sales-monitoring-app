import 'dart:convert';

SaleModel saleFromJson(String str) => SaleModel.fromJson(json.decode(str));

String saleToJson(SaleModel data) => json.encode(data.toJson());

class SaleModel {
  final String id;
  final String? transactionId;
  final String? stoveSerialNo;
  final DateTime? salesDate;
  final String? contactPerson;
  final String? contactPhone;
  final String? endUserName;
  final String? aka;
  final String? stateBackup;
  final String? lgaBackup;
  final String? phone;
  final String? otherPhone;
  final String? partnerName;
  final double amount;
  final String? signature;
  final String? status; // Database-managed status
  final String? createdBy;
  final String? organizationId;
  final String? addressId;
  final ImageData? stoveImageId;
  final ImageData? agreementImageId;
  final Address? address;
  final DateTime? createdAt;

  SaleModel({
    required this.id,
    this.transactionId,
    this.stoveSerialNo,
    this.salesDate,
    this.contactPerson,
    this.contactPhone,
    this.endUserName,
    this.aka,
    this.stateBackup,
    this.lgaBackup,
    this.phone,
    this.otherPhone,
    this.partnerName,
    required this.amount,
    this.signature,
    this.status,
    this.createdBy,
    this.organizationId,
    this.addressId,
    this.stoveImageId,
    this.agreementImageId,
    this.address,
    this.createdAt,
  });

  /// Factory to create from JSON
  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: json["id"],
        transactionId: json["transaction_id"],
        stoveSerialNo: json["stove_serial_no"],
        salesDate: json["sales_date"] != null
            ? DateTime.parse(json["sales_date"])
            : null,
        contactPerson: json["contact_person"],
        contactPhone: json["contact_phone"],
        endUserName: json["end_user_name"],
        aka: json["aka"],
        stateBackup: json["state_backup"],
        lgaBackup: json["lga_backup"],
        phone: json["phone"],
        otherPhone: json["other_phone"],
        partnerName: json["partner_name"],
        amount: json["amount"]?.toDouble() ?? 0.0,
        signature: json["signature"],
        status: json["status"],
        createdBy: json["created_by"],
        organizationId: json["organization_id"],
        addressId: json["address_id"],
        stoveImageId: json["stove_image_id"] != null
            ? ImageData.fromJson(json["stove_image_id"])
            : null,
        agreementImageId: json["agreement_image_id"] != null
            ? ImageData.fromJson(json["agreement_image_id"])
            : null,
        address:
            json["address"] != null ? Address.fromJson(json["address"]) : null,
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
      );

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        "id": id,
        "transaction_id": transactionId,
        "stove_serial_no": stoveSerialNo,
        "sales_date": salesDate?.toIso8601String(),
        "contact_person": contactPerson,
        "contact_phone": contactPhone,
        "end_user_name": endUserName,
        "aka": aka,
        "state_backup": stateBackup,
        "lga_backup": lgaBackup,
        "phone": phone,
        "other_phone": otherPhone,
        "partner_name": partnerName,
        "amount": amount,
        "signature": signature,
        "status": status,
        "created_by": createdBy,
        "organization_id": organizationId,
        "address_id": addressId,
        "stove_image_id": stoveImageId?.toJson(),
        "agreement_image_id": agreementImageId?.toJson(),
        "address": address?.toJson(),
        "created_at": createdAt?.toIso8601String(),
      };
}

class ImageData {
  final String id;
  final String url;
  final String type;
  final String publicId;
  final DateTime? createdAt;
  final String? createdBy;

  ImageData({
    required this.id,
    required this.url,
    required this.type,
    required this.publicId,
    this.createdAt,
    this.createdBy,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) => ImageData(
        id: json["id"],
        url: json["url"],
        type: json["type"],
        publicId: json["public_id"],
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
        createdBy: json["created_by"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "url": url,
        "type": type,
        "public_id": publicId,
        "created_at": createdAt?.toIso8601String(),
        "created_by": createdBy,
      };
}

class Address {
  final String id;
  final String? city;
  final String? state;
  final String? street;
  final String? country;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final String? fullAddress;

  Address({
    required this.id,
    this.city,
    this.state,
    this.street,
    this.country,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.fullAddress,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json["id"],
        city: json["city"],
        state: json["state"],
        street: json["street"],
        country: json["country"],
        latitude: json["latitude"]?.toDouble(),
        longitude: json["longitude"]?.toDouble(),
        createdAt: json["created_at"] != null
            ? DateTime.parse(json["created_at"])
            : null,
        fullAddress: json["full_address"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "city": city,
        "state": state,
        "street": street,
        "country": country,
        "latitude": latitude,
        "longitude": longitude,
        "created_at": createdAt?.toIso8601String(),
        "full_address": fullAddress,
      };
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) => PaginationInfo(
        page: json["page"],
        limit: json["limit"],
        total: json["total"],
        totalPages: json["totalPages"],
      );

  Map<String, dynamic> toJson() => {
        "page": page,
        "limit": limit,
        "total": total,
        "totalPages": totalPages,
      };
}
