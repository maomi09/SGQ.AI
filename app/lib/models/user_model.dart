class UserModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'student' or 'teacher'
  final String? studentId;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.studentId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      studentId: json['student_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'student_id': studentId,
    };
  }
}

