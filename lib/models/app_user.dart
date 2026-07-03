class AppUser {
  const AppUser({
    required this.id,
    required this.authId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.department,
    required this.position,
    required this.role,
    required this.status,
    required this.avatarUrl,
    required this.hasFaceEmbedding,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      authId: json['auth_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      position: json['position'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      status: json['status'] as String? ?? 'pending',
      avatarUrl: json['avatar_url'] as String?,
      hasFaceEmbedding: json['has_face_embedding'] as bool? ?? false,
    );
  }

  final String id;
  final String authId;
  final String email;
  final String firstName;
  final String lastName;
  final String department;
  final String position;
  final String role;
  final String status;
  final String? avatarUrl;
  final bool hasFaceEmbedding;

  bool get isProfileComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      (avatarUrl?.trim().isNotEmpty ?? false) &&
      hasFaceEmbedding;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? email : value;
  }
}
