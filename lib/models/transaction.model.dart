import 'package:cloud_firestore/cloud_firestore.dart';

class FinTransaction {
  String? id;
  String institutionId;
  String description;
  double amount;
  String type; // 'income' (entrada) ou 'expense' (saída)
  String status; // 'pending', 'paid'
  DateTime dueDate; // Vencimento
  DateTime? paidAt; // Data do pagamento real
  String category; // 'vendas', 'aluguel', 'fornecedor', etc.

  FinTransaction({
    this.id,
    required this.institutionId,
    required this.description,
    required this.amount,
    required this.type,
    this.status = 'pending',
    required this.dueDate,
    this.paidAt,
    this.category = 'Geral',
  });

  Map<String, dynamic> toMap() {
    return {
      'institutionId': institutionId,
      'description': description,
      'amount': amount,
      'type': type,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory FinTransaction.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FinTransaction(
      id: doc.id,
      institutionId: data['institutionId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'expense',
      status: data['status'] ?? 'pending',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      category: data['category'] ?? 'Geral',
    );
  }
}