// lib/models/sale_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/models/client.model.dart';
import 'package:quadra_vendas/models/product.model.dart';

// SaleItem permanece o mesmo
class SaleItem {
  final Product product;
  int quantity;
  SaleItem({required this.product, this.quantity = 1});
  double get totalPrice => product.salePrice * quantity;
  Map<String, dynamic> toMap() => {'productId': product.id, 'productName': product.name, 'quantity': quantity, 'unitPrice': product.salePrice, 'totalPrice': totalPrice};
  factory SaleItem.fromMap(Map<String, dynamic> map) {
    final tempProduct = Product(id: map['productId'], name: map['productName'], salePrice: (map['unitPrice'] as num? ?? 0).toDouble(), categoryId: '', categoryName: '');
    return SaleItem(product: tempProduct, quantity: (map['quantity'] as num? ?? 1).toInt());
  }
}

// Sale é atualizado
class Sale {
  final String? id;
  final Client? client;
  final String clientName;
  final String clientId;
  final List<SaleItem> items;
  final double totalAmount;
  final String paymentMethod; // <-- NOVO CAMPO
  final bool withInvoice;
  final String? observations;
  final DateTime saleDate;
  final String userId;

  Sale({
    this.id,
    this.client,
    required this.clientName,
    required this.clientId,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod, // <-- NOVO CAMPO
    required this.withInvoice,
    this.observations,
    required this.saleDate,
    required this.userId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': client!.id, 'clientName': client!.companyName,
      'totalAmount': totalAmount, 'paymentMethod': paymentMethod, // <-- NOVO CAMPO
      'withInvoice': withInvoice, 'observations': observations,
      'saleDate': Timestamp.fromDate(saleDate), 'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory Sale.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Sale(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? 'Cliente não encontrado',
      items: (data['items'] as List<dynamic>? ?? []).map((itemData) => SaleItem.fromMap(itemData as Map<String, dynamic>)).toList(),
      totalAmount: (data['totalAmount'] as num? ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'Não informada', // <-- NOVO CAMPO
      withInvoice: data['withInvoice'] ?? false,
      observations: data['observations'],
      saleDate: (data['saleDate'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
    );
  }
}
