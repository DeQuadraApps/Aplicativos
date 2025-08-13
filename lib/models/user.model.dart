import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String institutionId;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.institutionId,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'employee',
      institutionId: data['institutionId'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  // Quando você sobrescreve o ==, você também precisa sobrescrever o hashCode.
  @override
  int get hashCode => id.hashCode;
}