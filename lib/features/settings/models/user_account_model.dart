/// A user account from the `manage-users` edge function. Defensive parsing.
class UserAccountModel {
  UserAccountModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.phone,
    required this.role,
    required this.status,
  });

  final String id;
  final String fullName;
  final String email;
  final String username;
  final String phone;
  final String role;
  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  factory UserAccountModel.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return UserAccountModel(
      id: s(json['id'] ?? json['user_id']),
      fullName: s(json['full_name'] ?? json['fullName'] ?? json['username']),
      email: s(json['email']),
      username: s(json['username']),
      phone: s(json['phone'] ?? json['phone_number']),
      role: s(json['role']),
      status: s(json['status'] ?? (json['is_active'] == false ? 'inactive' : 'active')),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'username': username,
        'phone': phone,
        'role': role,
        'status': status,
      };
}
