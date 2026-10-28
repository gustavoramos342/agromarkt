enum UserRole { produtor, fornecedor, admin }

class UserModel {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final String? token;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;

    final roleName = (userData['role'] ?? 'produtor')
        .toString()
        .toLowerCase();

    final role = UserRole.values.firstWhere(
      (item) => item.name == roleName,
      orElse: () => UserRole.produtor,
    );

    return UserModel(
      id: int.tryParse('${userData['id']}') ?? 0,
      name: '${userData['name'] ?? ''}',
      email: '${userData['email'] ?? ''}',
      role: role,
      token: json['token']?.toString() ?? userData['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
  };
}
