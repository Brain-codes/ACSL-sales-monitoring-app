import 'dart:convert';

SalesHistoryModel salesHistoryFromJson(String str) =>
    SalesHistoryModel.fromJson(json.decode(str));

String salesHistoryToJson(SalesHistoryModel data) => json.encode(data.toJson());

class SalesHistoryModel {
  final String id;
  final String saleId;
  final String actionType;
  final String actionDescription;
  final Map<String, dynamic>? fieldChanges;
  final String performedBy;
  final DateTime performedAt;
  final SaleInfo? sale;
  final PerformerInfo? performer;

  SalesHistoryModel({
    required this.id,
    required this.saleId,
    required this.actionType,
    required this.actionDescription,
    this.fieldChanges,
    required this.performedBy,
    required this.performedAt,
    this.sale,
    this.performer,
  });

  factory SalesHistoryModel.fromJson(Map<String, dynamic> json) =>
      SalesHistoryModel(
        id: json["id"],
        saleId: json["sale_id"],
        actionType: json["action_type"],
        actionDescription: json["action_description"],
        fieldChanges: json["field_changes"],
        performedBy: json["performed_by"],
        performedAt: DateTime.parse(json["performed_at"]),
        sale: json["sales"] != null ? SaleInfo.fromJson(json["sales"]) : null,
        performer: json["profiles"] != null
            ? PerformerInfo.fromJson(json["profiles"])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "sale_id": saleId,
        "action_type": actionType,
        "action_description": actionDescription,
        "field_changes": fieldChanges,
        "performed_by": performedBy,
        "performed_at": performedAt.toIso8601String(),
        "sales": sale?.toJson(),
        "profiles": performer?.toJson(),
      };

  SalesHistoryModel copyWith({
    String? id,
    String? saleId,
    String? actionType,
    String? actionDescription,
    Map<String, dynamic>? fieldChanges,
    String? performedBy,
    DateTime? performedAt,
    SaleInfo? sale,
    PerformerInfo? performer,
  }) {
    return SalesHistoryModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      actionType: actionType ?? this.actionType,
      actionDescription: actionDescription ?? this.actionDescription,
      fieldChanges: fieldChanges ?? this.fieldChanges,
      performedBy: performedBy ?? this.performedBy,
      performedAt: performedAt ?? this.performedAt,
      sale: sale ?? this.sale,
      performer: performer ?? this.performer,
    );
  }
}

class SaleInfo {
  final String id;
  final String? transactionId;
  final String? stoveSerialNo;
  final String? contactPerson;
  final String? endUserName;
  final double amount;
  final String? status;
  final String? organizationId;

  SaleInfo({
    required this.id,
    this.transactionId,
    this.stoveSerialNo,
    this.contactPerson,
    this.endUserName,
    required this.amount,
    this.status,
    this.organizationId,
  });

  factory SaleInfo.fromJson(Map<String, dynamic> json) => SaleInfo(
        id: json["id"],
        transactionId: json["transaction_id"],
        stoveSerialNo: json["stove_serial_no"],
        contactPerson: json["contact_person"],
        endUserName: json["end_user_name"],
        amount: (json["amount"] ?? 0).toDouble(),
        status: json["status"],
        organizationId: json["organization_id"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "transaction_id": transactionId,
        "stove_serial_no": stoveSerialNo,
        "contact_person": contactPerson,
        "end_user_name": endUserName,
        "amount": amount,
        "status": status,
        "organization_id": organizationId,
      };
}

class PerformerInfo {
  final String id;
  final String? fullName;
  final String? email;
  final String? role;

  PerformerInfo({
    required this.id,
    this.fullName,
    this.email,
    this.role,
  });

  factory PerformerInfo.fromJson(Map<String, dynamic> json) => PerformerInfo(
        id: json["id"],
        fullName: json["full_name"],
        email: json["email"],
        role: json["role"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "full_name": fullName,
        "email": email,
        "role": role,
      };
}

class HistoryStatsModel {
  final int total;
  final int created;
  final int updated;
  final int completed;

  HistoryStatsModel({
    required this.total,
    required this.created,
    required this.updated,
    required this.completed,
  });

  factory HistoryStatsModel.fromJson(Map<String, dynamic> json) =>
      HistoryStatsModel(
        total: json["total"] ?? 0,
        created: json["created"] ?? 0,
        updated: json["updated"] ?? 0,
        completed: json["completed"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "total": total,
        "created": created,
        "updated": updated,
        "completed": completed,
      };
}

class HistoryPaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  HistoryPaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory HistoryPaginationModel.fromJson(Map<String, dynamic> json) =>
      HistoryPaginationModel(
        page: json["page"] ?? 1,
        limit: json["limit"] ?? 20,
        total: json["total"] ?? 0,
        totalPages: json["totalPages"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "page": page,
        "limit": limit,
        "total": total,
        "totalPages": totalPages,
      };
}

class HistoryResponseModel {
  final List<SalesHistoryModel> data;
  final HistoryPaginationModel pagination;
  final HistoryStatsModel stats;

  HistoryResponseModel({
    required this.data,
    required this.pagination,
    required this.stats,
  });

  factory HistoryResponseModel.fromJson(Map<String, dynamic> json) =>
      HistoryResponseModel(
        data: (json["data"] as List)
            .map((item) => SalesHistoryModel.fromJson(item))
            .toList(),
        pagination: HistoryPaginationModel.fromJson(json["pagination"]),
        stats: HistoryStatsModel.fromJson(json["stats"]),
      );

  Map<String, dynamic> toJson() => {
        "data": data.map((item) => item.toJson()).toList(),
        "pagination": pagination.toJson(),
        "stats": stats.toJson(),
      };
}
