// lib/models/goal.model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesGoal {
  final String? id;
  final String salespersonId;
  final String salespersonName;
  final int month;
  final int year;
  final double amount;

  SalesGoal({
    this.id,
    required this.salespersonId,
    required this.salespersonName,
    required this.month,
    required this.year,
    required this.amount,
  });

  // Converte de um documento do Firestore para o objeto SalesGoal
  factory SalesGoal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SalesGoal(
      id: doc.id,
      salespersonId: data['salespersonId'] ?? '',
      salespersonName: data['salespersonName'] ?? '',
      month: data['month'] ?? 0,
      year: data['year'] ?? 0,
      amount: (data['amount'] as num? ?? 0).toDouble(),
    );
  }

  // Converte o objeto SalesGoal para um mapa para o Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'salespersonId': salespersonId,
      'salespersonName': salespersonName,
      'month': month,
      'year': year,
      'amount': amount,
    };
  }
}