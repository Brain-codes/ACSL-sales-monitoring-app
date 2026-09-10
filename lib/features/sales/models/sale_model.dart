// To parse this JSON data, do
//
//     final saleModel = saleModelFromJson(jsonString);

import 'dart:convert';

SaleModel saleModelFromJson(String str) => SaleModel.fromJson(json.decode(str));

String saleModelToJson(SaleModel data) => json.encode(data.toJson());

class SaleModel {
  String id;
  String transactionId;
  String? stoveSerialNo;
  String? stoveId;
  String? endUserName;
  /// The name in two parts. The server writes these alongside the joined name
  /// (splitting the joined one by rule when only it arrives), so an edit can
  /// round-trip the parts instead of re-guessing them.
  String? endUserFirstName;
  String? endUserSurname;
  String? aka;
  String? contactPerson;
  String? contactPhone;
  String? phone;
  String? otherPhone;
  String? state;
  String? lga;
  String? address;
  /// City/town/village, from inside the address object.
  String? city;
  double? latitude;
  double? longitude;
  String? partnerName;
  String? retailerBranch;
  double? amount;
  double? amountReceived;
  String? selectedModelId;
  double? initialPaymentAmount;
  String? initialPaymentMethod;
  String? stoveImageId;
  String? stoveImageUrl;
  String? agreementImageId;
  String? agreementImageUrl;
  String? signatureId;
  int? potQuantity;
  bool? heatRetentionDevice;
  String? previousStoveType;
  String? previousStoveOther;
  String? signature; // base64 PNG from API, used in PDF generation
  Map<String, bool>? termsAccepted;
  String? mealsPerDay;
  String? cookingFuelSource;
  String? cookingLocation;
  String? status;
  String? agentId;
  DateTime? salesDate;
  DateTime? createdAt;

  // Payment & installment fields
  bool? isInstallment;
  String? paymentModelId;
  String? paymentStatus;
  double? totalPaid;
  bool? agentApproved;
  bool? isArchived;

  // Organization (partner branch) this sale belongs to — needed to satisfy
  // the partner-picker validation in edit mode, where the picker is locked.
  String? organizationId;

  // Nested objects flattened for display
  String? paymentModelName;
  double? paymentModelFixedPrice;
  int? paymentModelDurationMonths;
  String? organizationName;
  String? organizationBranch;
  String? creatorName;
  String? creatorRole;
  String? agentName; // flat fallback when creator object isn't expanded
  /// The agent who SOLD the stove, as written on the agreement. Distinct from
  /// [agentName]/`created_by`, which name whoever made the record.
  String? salesAgentName;

  // Transient (offline queue only, not serialized): the numeric queue row id and
  // the last sync error, used by the pending-sales list to edit/retry/delete.
  int? queueId;
  String? syncError;

  SaleModel({
    required this.id,
    required this.transactionId,
    this.stoveSerialNo,
    this.stoveId,
    this.endUserName,
    this.endUserFirstName,
    this.endUserSurname,
    this.aka,
    this.contactPerson,
    this.contactPhone,
    this.phone,
    this.otherPhone,
    this.state,
    this.lga,
    this.address,
    this.city,
    this.latitude,
    this.longitude,
    this.partnerName,
    this.retailerBranch,
    this.amount,
    this.amountReceived,
    this.selectedModelId,
    this.initialPaymentAmount,
    this.initialPaymentMethod,
    this.stoveImageId,
    this.stoveImageUrl,
    this.agreementImageId,
    this.agreementImageUrl,
    this.signatureId,
    this.potQuantity,
    this.heatRetentionDevice,
    this.previousStoveType,
    this.previousStoveOther,
    this.signature,
    this.termsAccepted,
    this.mealsPerDay,
    this.cookingFuelSource,
    this.cookingLocation,
    this.status,
    this.agentId,
    this.salesDate,
    this.createdAt,
    this.isInstallment,
    this.paymentModelId,
    this.paymentStatus,
    this.totalPaid,
    this.agentApproved,
    this.isArchived,
    this.paymentModelName,
    this.paymentModelFixedPrice,
    this.paymentModelDurationMonths,
    this.organizationId,
    this.organizationName,
    this.organizationBranch,
    this.creatorName,
    this.creatorRole,
    this.agentName,
    this.salesAgentName,
  });

  /// What the customer has actually paid so far.
  ///
  /// `total_paid` is the collected figure for BOTH installment and outright
  /// sales (create-sale persists `amountReceived` there). Never fall back to
  /// `amount` — an outright sale can be underpaid, and substituting the sale
  /// price would report it as settled.
  double get paidAmount => totalPaid ?? amountReceived ?? 0;

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final paymentModel = json["payment_model"] as Map<String, dynamic>?;
    final org = json["organizations"] as Map<String, dynamic>?;
    final creator = json["creator"] as Map<String, dynamic>?;

    // Image fields can arrive as an expanded object { id, url, ... } (get-sale /
    // get-sales-advanced), as a plain id string, or — for cached sales — split
    // into <field>_url. Normalise to an id + url pair.
    final agreementImg = json["agreement_image"] ?? json["agreement_image_id"];
    final stoveImg = json["stove_image"];

    return SaleModel(
      id: json["id"]?.toString() ?? "",
      transactionId: json["transaction_id"]?.toString() ?? json["transactionId"]?.toString() ?? "",
      stoveSerialNo: json["stove_serial_no"] ?? json["stoveSerialNo"],
      stoveId: json["stove_id"] ?? json["stoveId"],
      endUserName: json["end_user_name"] ?? json["endUserName"],
      endUserFirstName:
          json["end_user_first_name"] ?? json["endUserFirstName"],
      endUserSurname: json["end_user_surname"] ?? json["endUserSurname"],
      aka: json["aka"],
      contactPerson: json["contact_person"] ?? json["contactPerson"],
      contactPhone: json["contact_phone"] ?? json["contactPhone"],
      phone: json["phone"],
      otherPhone: json["other_phone"] ?? json["otherPhone"],
      state: json["state_backup"] ?? json["state"],
      lga: json["lga_backup"] ?? json["lga"],
      // "address" can be a plain string (list endpoint) or the joined addresses
      // object from get-sale: address:addresses(*) → { full_address, street, … }
      address: json["address"] is String
          ? json["address"] as String
          : json["address"] is Map
              ? ((json["address"] as Map)["full_address"] ??
                      (json["address"] as Map)["street"])
                  ?.toString()
              : json["full_address"]?.toString() ??
                  (json["address_data"] is Map
                      ? (json["address_data"] as Map)["street"]?.toString()
                      : null),
      city: json["city"]?.toString() ??
          (json["address"] is Map
              ? (json["address"] as Map)["city"]?.toString()
              : null) ??
          (json["address_data"] is Map
              ? (json["address_data"] as Map)["city"]?.toString()
              : null),
      latitude: json["latitude"] != null
          ? (json["latitude"] as num).toDouble()
          : (json["address_data"] as Map?)?.containsKey("latitude") == true
              ? ((json["address_data"] as Map)["latitude"] as num?)?.toDouble()
              : null,
      longitude: json["longitude"] != null
          ? (json["longitude"] as num).toDouble()
          : (json["address_data"] as Map?)?.containsKey("longitude") == true
              ? ((json["address_data"] as Map)["longitude"] as num?)?.toDouble()
              : null,
      partnerName: json["partner_name"] ?? json["partnerName"] ?? org?["partner_name"]?.toString(),
      retailerBranch: json["retailer_branch"] ?? json["retailerBranch"],
      organizationId: json["organization_id"]?.toString() ?? json["organizationId"]?.toString(),
      amount: json["amount"] != null ? (json["amount"] as num).toDouble() : null,
      amountReceived: json["amount_received"] != null ? (json["amount_received"] as num).toDouble() : null,
      selectedModelId: json["selected_model_id"]?.toString() ?? json["payment_model_id"]?.toString(),
      initialPaymentAmount: json["initial_payment_amount"] != null ? (json["initial_payment_amount"] as num).toDouble() : null,
      initialPaymentMethod: json["initial_payment_method"],
      stoveImageId: json["stove_image_id"]?.toString(),
      stoveImageUrl: stoveImg is Map ? stoveImg["url"]?.toString() : null,
      agreementImageId: agreementImg is Map
          ? agreementImg["id"]?.toString()
          : agreementImg?.toString(),
      agreementImageUrl: agreementImg is Map
          ? agreementImg["url"]?.toString()
          : json["agreement_image_url"]?.toString(),
      // API returns base64 in "signature" and uuid in "signature_id"
      signatureId: json["signature_id"]?.toString() ?? (json["signature"] != null ? 'captured' : null),
      signature: json["signature"]?.toString(),
      potQuantity: json["pot_quantity"] != null ? (json["pot_quantity"] as num).toInt() : null,
      heatRetentionDevice: json["heat_retention_device"],
      previousStoveType: json["previous_stove_type"],
      previousStoveOther: json["previous_stove_other"]?.toString(),
      termsAccepted: json["terms_accepted"] is Map
          ? (json["terms_accepted"] as Map).map(
              (k, v) => MapEntry(k.toString(), v == true))
          : null,
      mealsPerDay: json["meals_per_day"]?.toString(),
      cookingFuelSource: json["cooking_fuel_source"],
      cookingLocation: json["cooking_location"],
      status: json["status"],
      agentId: json["agent_id"]?.toString() ?? json["created_by"]?.toString(),
      salesDate: json["sales_date"] != null ? DateTime.tryParse(json["sales_date"]) : null,
      createdAt: json["created_at"] != null ? DateTime.tryParse(json["created_at"]) : null,
      isInstallment: json["is_installment"],
      paymentModelId: json["payment_model_id"]?.toString(),
      paymentStatus: json["payment_status"],
      totalPaid: json["total_paid"] != null ? (json["total_paid"] as num).toDouble() : null,
      agentApproved: json["agent_approved"],
      isArchived: json["is_archived"],
      paymentModelName: paymentModel?["name"]?.toString(),
      paymentModelFixedPrice: paymentModel?["fixed_price"] != null ? (paymentModel!["fixed_price"] as num).toDouble() : null,
      paymentModelDurationMonths: paymentModel?["duration_months"] != null ? (paymentModel!["duration_months"] as num).toInt() : null,
      organizationName: org?["branch"]?.toString(),
      organizationBranch: org?["branch"]?.toString(),
      creatorName: creator?["full_name"]?.toString() ?? json["creator_name"]?.toString(),
      creatorRole: creator?["role"]?.toString() ?? json["creator_role"]?.toString(),
      agentName: json["agent_name"]?.toString(),
      salesAgentName: json["selling_agent_name"] ?? json["salesAgentName"],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "transaction_id": transactionId,
        "stove_serial_no": stoveSerialNo,
        "stove_id": stoveId,
        "end_user_name": endUserName,
        "aka": aka,
        "contact_person": contactPerson,
        "contact_phone": contactPhone,
        "phone": phone,
        "other_phone": otherPhone,
        "state": state,
        "lga": lga,
        "address": address,
        "latitude": latitude,
        "longitude": longitude,
        "partner_name": partnerName,
        "retailer_branch": retailerBranch,
        "organization_id": organizationId,
        "amount": amount,
        "amount_received": amountReceived,
        "selected_model_id": selectedModelId,
        "initial_payment_amount": initialPaymentAmount,
        "initial_payment_method": initialPaymentMethod,
        "stove_image_id": stoveImageId,
        "stove_image_url": stoveImageUrl,
        "agreement_image_id": agreementImageId,
        "agreement_image_url": agreementImageUrl,
        "signature_id": signatureId,
        "pot_quantity": potQuantity,
        "heat_retention_device": heatRetentionDevice,
        "previous_stove_type": previousStoveType,
        "previous_stove_other": previousStoveOther,
        "meals_per_day": mealsPerDay,
        "cooking_fuel_source": cookingFuelSource,
        "cooking_location": cookingLocation,
        "status": status,
        "agent_id": agentId,
        "sales_date": salesDate?.toIso8601String(),
        "created_at": createdAt?.toIso8601String(),
        "is_installment": isInstallment,
        "payment_model_id": paymentModelId,
        "payment_status": paymentStatus,
        "total_paid": totalPaid,
        "agent_approved": agentApproved,
        "is_archived": isArchived,
        // Flat keys so the cache round-trip preserves creator info without needing the nested object.
        "agent_name": agentName,
        if (creatorName != null) "creator_name": creatorName,
        if (creatorRole != null) "creator_role": creatorRole,
      };
}
