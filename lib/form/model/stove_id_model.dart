class StoveIdModel {
  final String id;
  final String stoveId;
  final String status;
  final DateTime? createdAt;

  StoveIdModel({
    required this.id,
    required this.stoveId,
    required this.status,
    this.createdAt,
  });

  factory StoveIdModel.fromJson(Map<String, dynamic> json) => StoveIdModel(
        id: json['id'] as String,
        stoveId: json['stove_id'] as String,
        status: json['status'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stove_id': stoveId,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
      };
}