import 'dart:convert';

class OfflineSaleModel {
  final String offlineId;
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
  final String? createdBy;
  final String? organizationId;
  final Map<String, dynamic>? addressData;
  final String? stoveImagePath;
  final String? agreementImagePath;
  final String? stoveImageId;
  final String? agreementImageId;
  final DateTime createdOfflineAt;
  final String syncStatus; // 'pending', 'synced', 'failed'
  final bool isOffline;
  final String? serverId;
  final DateTime? syncedAt;
  final String? syncError;
  final DateTime? failedAt;

  OfflineSaleModel({
    required this.offlineId,
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
    this.createdBy,
    this.organizationId,
    this.addressData,
    this.stoveImagePath,
    this.agreementImagePath,
    this.stoveImageId,
    this.agreementImageId,
    required this.createdOfflineAt,
    this.syncStatus = 'pending',
    this.isOffline = true,
    this.serverId,
    this.syncedAt,
    this.syncError,
    this.failedAt,
  });

  /// Dynamic status getter similar to SaleModel
  String get status {
    if (syncStatus == 'failed') return 'sync_failed';
    if (syncStatus == 'synced') return 'synced';

    final requiredFields = [
      stoveSerialNo,
      salesDate?.toIso8601String(),
      contactPerson,
      contactPhone,
      endUserName,
      stateBackup,
      lgaBackup,
      phone,
      partnerName,
      signature,
      stoveImagePath ?? stoveImageId,
      agreementImagePath ?? agreementImageId,
      addressData?['fullAddress'],
    ];

    // Check if any required field is missing or empty
    bool hasIncompleteField = requiredFields.any(
      (field) => field == null || field.toString().trim().isEmpty,
    );

    return hasIncompleteField ? 'pending' : 'completed';
  }

  /// Get display status text
  String get displayStatus {
    switch (syncStatus) {
      case 'synced':
        return 'Synced';
      case 'failed':
        return 'Sync Failed';
      case 'pending':
      default:
        return status == 'completed' ? 'Ready to Sync' : 'Incomplete';
    }
  }

  /// Check if sale is ready for sync
  bool get isReadyForSync {
    return syncStatus == 'pending' && status == 'completed';
  }

  /// Factory to create from JSON
  factory OfflineSaleModel.fromJson(Map<String, dynamic> json) {
    return OfflineSaleModel(
      offlineId: json['offline_id'] ?? '',
      transactionId: json['transactionId'],
      stoveSerialNo: json['stoveSerialNo'],
      salesDate: json['salesDate'] != null
          ? DateTime.tryParse(json['salesDate'])
          : null,
      contactPerson: json['contactPerson'],
      contactPhone: json['contactPhone'],
      endUserName: json['endUserName'],
      aka: json['aka'],
      stateBackup: json['stateBackup'],
      lgaBackup: json['lgaBackup'],
      phone: json['phone'],
      otherPhone: json['otherPhone'],
      partnerName: json['partnerName'],
      amount: (json['amount'] ?? 0).toDouble(),
      signature: json['signature'],
      createdBy: json['createdBy'],
      organizationId: json['organizationId'],
      addressData: json['addressData'],
      stoveImagePath: json['stove_image_path'],
      agreementImagePath: json['agreement_image_path'],
      stoveImageId: json['stoveImageId'],
      agreementImageId: json['agreementImageId'],
      createdOfflineAt: DateTime.parse(json['created_offline_at']),
      syncStatus: json['sync_status'] ?? 'pending',
      isOffline: json['is_offline'] ?? true,
      serverId: json['server_id'],
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'])
          : null,
      syncError: json['sync_error'],
      failedAt: json['failed_at'] != null
          ? DateTime.tryParse(json['failed_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'offline_id': offlineId,
      'transactionId': transactionId,
      'stoveSerialNo': stoveSerialNo,
      'salesDate': salesDate?.toIso8601String(),
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'endUserName': endUserName,
      'aka': aka,
      'stateBackup': stateBackup,
      'lgaBackup': lgaBackup,
      'phone': phone,
      'otherPhone': otherPhone,
      'partnerName': partnerName,
      'amount': amount,
      'signature': signature,
      'createdBy': createdBy,
      'organizationId': organizationId,
      'addressData': addressData,
      'stove_image_path': stoveImagePath,
      'agreement_image_path': agreementImagePath,
      'stoveImageId': stoveImageId,
      'agreementImageId': agreementImageId,
      'created_offline_at': createdOfflineAt.toIso8601String(),
      'sync_status': syncStatus,
      'is_offline': isOffline,
      'server_id': serverId,
      'synced_at': syncedAt?.toIso8601String(),
      'sync_error': syncError,
      'failed_at': failedAt?.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  OfflineSaleModel copyWith({
    String? offlineId,
    String? transactionId,
    String? stoveSerialNo,
    DateTime? salesDate,
    String? contactPerson,
    String? contactPhone,
    String? endUserName,
    String? aka,
    String? stateBackup,
    String? lgaBackup,
    String? phone,
    String? otherPhone,
    String? partnerName,
    double? amount,
    String? signature,
    String? createdBy,
    String? organizationId,
    Map<String, dynamic>? addressData,
    String? stoveImagePath,
    String? agreementImagePath,
    String? stoveImageId,
    String? agreementImageId,
    DateTime? createdOfflineAt,
    String? syncStatus,
    bool? isOffline,
    String? serverId,
    DateTime? syncedAt,
    String? syncError,
    DateTime? failedAt,
  }) {
    return OfflineSaleModel(
      offlineId: offlineId ?? this.offlineId,
      transactionId: transactionId ?? this.transactionId,
      stoveSerialNo: stoveSerialNo ?? this.stoveSerialNo,
      salesDate: salesDate ?? this.salesDate,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      endUserName: endUserName ?? this.endUserName,
      aka: aka ?? this.aka,
      stateBackup: stateBackup ?? this.stateBackup,
      lgaBackup: lgaBackup ?? this.lgaBackup,
      phone: phone ?? this.phone,
      otherPhone: otherPhone ?? this.otherPhone,
      partnerName: partnerName ?? this.partnerName,
      amount: amount ?? this.amount,
      signature: signature ?? this.signature,
      createdBy: createdBy ?? this.createdBy,
      organizationId: organizationId ?? this.organizationId,
      addressData: addressData ?? this.addressData,
      stoveImagePath: stoveImagePath ?? this.stoveImagePath,
      agreementImagePath: agreementImagePath ?? this.agreementImagePath,
      stoveImageId: stoveImageId ?? this.stoveImageId,
      agreementImageId: agreementImageId ?? this.agreementImageId,
      createdOfflineAt: createdOfflineAt ?? this.createdOfflineAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isOffline: isOffline ?? this.isOffline,
      serverId: serverId ?? this.serverId,
      syncedAt: syncedAt ?? this.syncedAt,
      syncError: syncError ?? this.syncError,
      failedAt: failedAt ?? this.failedAt,
    );
  }

  @override
  String toString() {
    return 'OfflineSaleModel(offlineId: $offlineId, endUserName: $endUserName, syncStatus: $syncStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineSaleModel && other.offlineId == offlineId;
  }

  @override
  int get hashCode => offlineId.hashCode;
}

class OfflineSaleEditModel {
  final String editId;
  final String saleId;
  final Map<String, dynamic> editData;
  final DateTime editedOfflineAt;
  final String syncStatus; // 'pending', 'synced', 'failed'
  final bool isOfflineEdit;
  final DateTime? syncedAt;
  final String? syncError;

  OfflineSaleEditModel({
    required this.editId,
    required this.saleId,
    required this.editData,
    required this.editedOfflineAt,
    this.syncStatus = 'pending',
    this.isOfflineEdit = true,
    this.syncedAt,
    this.syncError,
  });

  /// Factory to create from JSON
  factory OfflineSaleEditModel.fromJson(Map<String, dynamic> json) {
    return OfflineSaleEditModel(
      editId: json['edit_id'] ?? '',
      saleId: json['sale_id'] ?? '',
      editData: Map<String, dynamic>.from(json['editData'] ?? {}),
      editedOfflineAt: DateTime.parse(json['edited_offline_at']),
      syncStatus: json['sync_status'] ?? 'pending',
      isOfflineEdit: json['is_offline_edit'] ?? true,
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'])
          : null,
      syncError: json['sync_error'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'edit_id': editId,
      'sale_id': saleId,
      'editData': editData,
      'edited_offline_at': editedOfflineAt.toIso8601String(),
      'sync_status': syncStatus,
      'is_offline_edit': isOfflineEdit,
      'synced_at': syncedAt?.toIso8601String(),
      'sync_error': syncError,
    };
  }

  @override
  String toString() {
    return 'OfflineSaleEditModel(editId: $editId, saleId: $saleId, syncStatus: $syncStatus)';
  }
}
