import 'dart:convert';

DashboardStatsModel dashboardStatsModelFromJson(String str) =>
    DashboardStatsModel.fromJson(json.decode(str));

String dashboardStatsModelToJson(DashboardStatsModel data) =>
    json.encode(data.toJson());

class DashboardStatsModel {
  final int totalSales;
  final int salesAgents;
  final int completedSales;
  final int stovesWithLandmark;
  final int pendingSales;
  final double totalSalesAmount;
  final String? organizationId;
  final int? totalStovesReceived;
  final int? totalStovesSold;
  final int? totalStovesAvailable;

  DashboardStatsModel({
    required this.totalSales,
    required this.salesAgents,
    required this.completedSales,
    required this.stovesWithLandmark,
    required this.pendingSales,
    required this.totalSalesAmount,
    this.organizationId,
    this.totalStovesReceived,
    this.totalStovesSold,
    this.totalStovesAvailable,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) =>
      DashboardStatsModel(
        totalSales: json["totalSales"] ?? 0,
        salesAgents: json["salesAgents"] ?? 0,
        completedSales: json["completedSales"] ?? 0,
        stovesWithLandmark: json["stovesWithLandmark"] ?? 0,
        pendingSales: json["pendingSales"] ?? 0,
        totalSalesAmount: (json["totalSalesAmount"] ?? 0).toDouble(),
        organizationId: json["organizationId"],
        totalStovesReceived: json["totalStovesReceived"],
        totalStovesSold: json["totalStovesSold"],
        totalStovesAvailable: json["totalStovesAvailable"],
      );

  Map<String, dynamic> toJson() => {
        "totalSales": totalSales,
        "salesAgents": salesAgents,
        "completedSales": completedSales,
        "stovesWithLandmark": stovesWithLandmark,
        "pendingSales": pendingSales,
        "totalSalesAmount": totalSalesAmount,
        "organizationId": organizationId,
        "totalStovesReceived": totalStovesReceived,
        "totalStovesSold": totalStovesSold,
        "totalStovesAvailable": totalStovesAvailable,
      };

  DashboardStatsModel copyWith({
    int? totalSales,
    int? salesAgents,
    int? completedSales,
    int? stovesWithLandmark,
    int? pendingSales,
    double? totalSalesAmount,
    String? organizationId,
    int? totalStovesReceived,
    int? totalStovesSold,
    int? totalStovesAvailable,
  }) {
    return DashboardStatsModel(
      totalSales: totalSales ?? this.totalSales,
      salesAgents: salesAgents ?? this.salesAgents,
      completedSales: completedSales ?? this.completedSales,
      stovesWithLandmark: stovesWithLandmark ?? this.stovesWithLandmark,
      pendingSales: pendingSales ?? this.pendingSales,
      totalSalesAmount: totalSalesAmount ?? this.totalSalesAmount,
      organizationId: organizationId ?? this.organizationId,
      totalStovesReceived: totalStovesReceived ?? this.totalStovesReceived,
      totalStovesSold: totalStovesSold ?? this.totalStovesSold,
      totalStovesAvailable: totalStovesAvailable ?? this.totalStovesAvailable,
    );
  }

  @override
  String toString() {
    return 'DashboardStatsModel(totalSales: $totalSales, salesAgents: $salesAgents, completedSales: $completedSales, stovesWithLandmark: $stovesWithLandmark, pendingSales: $pendingSales, totalSalesAmount: $totalSalesAmount, organizationId: $organizationId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DashboardStatsModel &&
        other.totalSales == totalSales &&
        other.salesAgents == salesAgents &&
        other.completedSales == completedSales &&
        other.stovesWithLandmark == stovesWithLandmark &&
        other.pendingSales == pendingSales &&
        other.totalSalesAmount == totalSalesAmount &&
        other.organizationId == organizationId;
  }

  @override
  int get hashCode {
    return totalSales.hashCode ^
        salesAgents.hashCode ^
        completedSales.hashCode ^
        stovesWithLandmark.hashCode ^
        pendingSales.hashCode ^
        totalSalesAmount.hashCode ^
        organizationId.hashCode;
  }
}
