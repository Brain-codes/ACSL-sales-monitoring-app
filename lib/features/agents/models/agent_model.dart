/// An agent (ACSL agent / partner agent) as returned by the `super-admin-agents`
/// and `manage-agents` edge functions. Defensive parsing — backend field names
/// vary, so we fall back gracefully.
class AgentModel {
  AgentModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.assignedStatesCount,
    required this.assignedOrganizationsCount,
    required this.totalSales,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String status;
  final int assignedStatesCount;
  final int assignedOrganizationsCount;
  final int totalSales;
  final String? createdAt;

  bool get isActive => status.toLowerCase() == 'active';

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    int i(dynamic v) => v is int ? v : int.tryParse(s(v)) ?? 0;
    return AgentModel(
      id: s(json['id'] ?? json['user_id'] ?? json['agent_id']),
      fullName: s(json['full_name'] ?? json['fullName'] ?? json['username'] ?? json['name']),
      email: s(json['email']),
      phone: s(json['phone'] ?? json['phone_number']),
      role: s(json['role']),
      status: s(json['status'] ?? (json['is_active'] == false ? 'inactive' : 'active')),
      assignedStatesCount: i(json['assigned_states_count']),
      assignedOrganizationsCount: i(json['assigned_organizations_count']),
      totalSales: i(json['total_sales'] ?? json['sales_count']),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'assigned_states_count': assignedStatesCount,
        'assigned_organizations_count': assignedOrganizationsCount,
        'total_sales': totalSales,
        'created_at': createdAt,
      };
}
