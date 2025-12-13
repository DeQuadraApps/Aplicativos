import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String institutionId;
  final Map<String, dynamic> permissions; // ✨ 1. Novo campo adicionado

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.institutionId,
    this.permissions = const {}, // ✨ 2. Inicia vazio por padrão para evitar null
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'employee',
      institutionId: data['institutionId'] ?? '',
      // ✨ 3. Converte o Map do Firestore de forma segura
      permissions: data['permissions'] != null
          ? Map<String, dynamic>.from(data['permissions'])
          : {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}