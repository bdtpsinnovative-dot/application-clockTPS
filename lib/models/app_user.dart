class AppUser {
  const AppUser({
    required this.id,
    required this.authId,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.nickname = '',
    required this.department,
    required this.position,
    required this.role,
    required this.status,
    required this.avatarUrl,
    required this.hasFaceEmbedding,
    this.workStartTime = '09:00',
    this.workEndTime = '18:00',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      authId: json['auth_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      department: json['department'] as String? ?? '',
      position: json['position'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      status: json['status'] as String? ?? 'pending',
      avatarUrl: json['avatar_url'] as String?,
      hasFaceEmbedding: json['has_face_embedding'] as bool? ?? false,
      workStartTime: json['work_start_time'] as String? ?? '09:00',
      workEndTime: json['work_end_time'] as String? ?? '18:00',
    );
  }

  final String id;
  final String authId;
  final String email;
  final String firstName;
  final String lastName;
  final String nickname;
  final String department;
  final String position;
  final String role;
  final String status;
  final String? avatarUrl;
  final bool hasFaceEmbedding;
  final String workStartTime;
  final String workEndTime;

  bool get isProfileComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      nickname.trim().isNotEmpty &&
      (avatarUrl?.trim().isNotEmpty ?? false) &&
      hasFaceEmbedding;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    if (name.isEmpty) return email;
    if (nickname.trim().isNotEmpty) {
      return '$name ($nickname)';
    }
    return name;
  }
}
