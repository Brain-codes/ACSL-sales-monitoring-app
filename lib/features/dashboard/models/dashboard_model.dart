// To parse this JSON data, do
//
//     final dashboardStats = dashboardStatsFromJson(jsonString);

import 'dart:convert';

DashboardStats dashboardStatsFromJson(String str) => DashboardStats.fromJson(json.decode(str));

String dashboardStatsToJson(DashboardStats data) => json.encode(data.toJson());

class DashboardStats {
  int stovesReceived;
  int stovesSold;
  int availableStoves;
  double expectedReceivable;
  double amountReceived;
  double outstandingBalance;
  List<SalesByState> salesByState;
  List<SalesByModel> salesByModel;

  DashboardStats({
    required this.stovesReceived,
    required this.stovesSold,
    required this.availableStoves,
    required this.expectedReceivable,
    required this.amountReceived,
    required this.outstandingBalance,
    required this.salesByState,
    required this.salesByModel,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        stovesReceived: _int(
          json["stovesReceived"] ?? json["totalStovesReceived"] ?? json["stoves_received"],
        ),
        stovesSold: _int(
          json["stovesSold"] ?? json["totalStovesSold"] ?? json["stoves_sold"],
        ),
        availableStoves: _int(
          json["availableStoves"] ?? json["totalStovesAvailable"] ?? json["available_stoves"],
        ),
        expectedReceivable: _double(
          json["expectedReceivable"] ?? json["totalExpectedAmount"] ?? json["expected_receivable"],
        ),
        amountReceived: _double(
          json["amountReceived"] ?? json["totalAmountPaid"] ?? json["amount_received"],
        ),
        outstandingBalance: _double(
          json["outstandingBalance"] ?? json["totalAmountOwed"] ?? json["outstanding_balance"],
        ),
        salesByState: (json["byState"] ?? json["salesByState"] ?? json["by_state"] as List?)
                ?.map<SalesByState>((x) => SalesByState.fromJson(x))
                .toList() ??
            [],
        salesByModel: (json["salesModelData"] ?? json["salesByModel"] ?? json["by_model"] as List?)
                ?.map<SalesByModel>((x) => SalesByModel.fromJson(x))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        "totalStovesReceived": stovesReceived,
        "totalStovesSold": stovesSold,
        "totalStovesAvailable": availableStoves,
        "totalExpectedAmount": expectedReceivable,
        "totalAmountPaid": amountReceived,
        "totalAmountOwed": outstandingBalance,
        "salesByState": List<dynamic>.from(salesByState.map((x) => x.toJson())),
        "salesByModel": List<dynamic>.from(salesByModel.map((x) => x.toJson())),
      };

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  static double _double(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────

SalesByState salesByStateFromJson(String str) => SalesByState.fromJson(json.decode(str));

String salesByStateToJson(SalesByState data) => json.encode(data.toJson());

class SalesByState {
  String state;
  int count;

  SalesByState({
    required this.state,
    required this.count,
  });

  factory SalesByState.fromJson(Map<String, dynamic> json) => SalesByState(
        state: json["state"] ?? "",
        count: (json["count"] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "state": state,
        "count": count,
      };
}

// ─────────────────────────────────────────────────────────────────────────────

SalesByModel salesByModelFromJson(String str) => SalesByModel.fromJson(json.decode(str));

String salesByModelToJson(SalesByModel data) => json.encode(data.toJson());

class SalesByModel {
  String modelName;
  int count;

  SalesByModel({
    required this.modelName,
    required this.count,
  });

  factory SalesByModel.fromJson(Map<String, dynamic> json) => SalesByModel(
        modelName: json["model"] ?? json["name"] ?? "",
        count: (json["count"] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "model": modelName,
        "count": count,
      };
}
