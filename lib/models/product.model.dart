// lib/models/product.model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Product {
  final String? id;
  final String name;
  final String categoryId;
  final String categoryName;
  final double salePrice;
  final double? costPrice;
  final String? margin;
  final Map<String, dynamic>? otherPrices;
  final String? createdBy;

  Product({
    this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.salePrice,
    this.costPrice,
    this.margin,
    this.otherPrices,
    this.createdBy,
  });

  // +++ MÉTODO fromFirestore CORRIGIDO E À PROVA DE FALHAS +++
  factory Product.fromFirestore(DocumentSnapshot doc) {
    // Tenta ler os dados. Se for nulo (documento vazio), trata como um mapa vazio.
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Se o documento estiver vazio, imprime um aviso no console de depuração.
    if (data.isEmpty) {
      debugPrint("AVISO: Documento de produto com ID '${doc.id}' está vazio ou sem dados.");
    }

    return Product(
      id: doc.id,
      name: data['name'] ?? 'Produto Inválido', // Valor padrão em caso de erro
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      salePrice: (data['salePrice'] as num? ?? 0).toDouble(),
      costPrice: (data['costPrice'] as num?)?.toDouble(),
      margin: data['margin'],
      otherPrices: data.containsKey('otherPrices') && data['otherPrices'] is Map
          ? Map<String, dynamic>.from(data['otherPrices'])
          : null,
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'salePrice': salePrice,
      'costPrice': costPrice,
      'margin': margin,
      'otherPrices': otherPrices,
      'createdBy': createdBy,
    };
  }
}