import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String institutionId;
  final Map<String, dynamic> permissions;
  final double? commissionRate; // ✨ 1. Campo de comissão (nullable)

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.institutionId,
    this.permissions = const {},
    this.commissionRate, // ✨ 2. Adicionado no construtor
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'employee',
      institutionId: data['institutionId'] ?? '',
      permissions: data['permissions'] != null
          ? Map<String, dynamic>.from(data['permissions'])
          : {},
      // ✨ 3. Converte num? para double? (Evita erro se vier int do Firestore)
      commissionRate: (data['commissionRate'] as num?)?.toDouble(),
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