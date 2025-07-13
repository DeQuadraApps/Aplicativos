// lib/models/product_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String name;
  final String categoryId;
  final double salePrice;
  final double? costPrice;
  final String? margin;
  final Map<String, dynamic>? otherPrices; // <-- CAMPO ADICIONADO

  Product({
    this.id,
    required this.name,
    required this.categoryId,
    required this.salePrice,
    this.costPrice,
    this.margin,
    this.otherPrices,
    required String categoryName, // <-- ADICIONADO AO CONSTRUTOR
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      categoryId: data['categoryId'] ?? '',
      salePrice: (data['salePrice'] ?? 0.0).toDouble(),
      costPrice: (data['costPrice'] as num?)?.toDouble(),
      margin: data['margin'],
      // Lê o mapa de outros preços do Firestore
      otherPrices: data.containsKey('otherPrices') ? Map<String, dynamic>.from(data['otherPrices']) : null,
      categoryName: '', // <-- LEITURA ADICIONADA
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'categoryId': categoryId,
      'salePrice': salePrice,
      'costPrice': costPrice,
      'margin': margin,
      'otherPrices': otherPrices, // <-- ADICIONADO AO MAPA
    };
  }
}