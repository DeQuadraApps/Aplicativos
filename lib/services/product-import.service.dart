// lib/services/product-import.service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quadra_vendas/enums/category-import-action.enum.dart';

typedef CategoryConflictResolver = Future<CategoryImportAction?> Function(String categoryName);

class ProductImportService {
  final String institutionId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProductImportService({required this.institutionId});

  String _removeDiacritics(String str) {
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  Future<String?> _getOrCreateCategory(String categoryName, WriteBatch batch,
      Map<String, String> cache, CategoryConflictResolver onConflict) async {
    final trimmedName = categoryName.trim();
    if (cache.containsKey(trimmedName)) return cache[trimmedName]!;

    final collectionRef = _firestore.collection('institutions').doc(
        institutionId).collection('productCategories');
    final query = await collectionRef
        .where('name', isEqualTo: trimmedName)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final existingCategoryId = query.docs.first.id;
      CategoryImportAction? action;
      try {
        action = await onConflict(trimmedName);
      } catch (e, s) {
        debugPrint("A função 'onCategoryConflict' FALHOU: $e\n$s");
        action = CategoryImportAction.cancel;
      }

      switch (action) {
        case CategoryImportAction.overwrite:
          final productsSnapshot = await _firestore
              .collection('institutions')
              .doc(institutionId)
              .collection('products')
              .where('categoryId', isEqualTo: existingCategoryId)
              .get();
          for (final doc in productsSnapshot.docs) {
            batch.delete(doc.reference);
          }
          cache[trimmedName] = existingCategoryId;
          return existingCategoryId;
        case CategoryImportAction.createNew:
          final newName = '$trimmedName (Cópia)';
          final newCategoryRef = collectionRef.doc();
          batch.set(newCategoryRef, {'name': newName});
          cache[newName] = newCategoryRef.id;
          return newCategoryRef.id;
        case CategoryImportAction.cancel:
        case null:
          return null;
      }
    } else {
      final newCategoryRef = collectionRef.doc();
      batch.set(newCategoryRef, {'name': trimmedName});
      cache[trimmedName] = newCategoryRef.id;
      return newCategoryRef.id;
    }
  }

  double? _parsePriceFromCell(Data? cell) {
    if (cell == null) return null;
    final String valueAsString = cell.value?.toString().trim() ?? '';
    if (valueAsString.isEmpty) return null;
    double? directParse = double.tryParse(valueAsString);
    if (directParse != null) return directParse;
    String processedString = valueAsString;
    int lastComma = processedString.lastIndexOf(',');
    int lastDot = processedString.lastIndexOf('.');
    if (lastComma > lastDot) {
      processedString = processedString.replaceAll('.', '').replaceAll(',', '.');
    } else {
      processedString = processedString.replaceAll(',', '');
    }
    final cleanedString = processedString.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleanedString.isEmpty || cleanedString.split('.').length > 2) return null;
    return double.tryParse(cleanedString);
  }

  Future<String?> importFromExcel(
      {required CategoryConflictResolver onConflict}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result == null) return "Seleção de arquivo cancelada.";

    try {
      final bytes = result.files.single.bytes!;
      final excel = Excel.decodeBytes(bytes);
      final WriteBatch batch = _firestore.batch();
      final Map<String, String> categoryCache = {};
      int totalProductsAdded = 0;

      const productHeaderKeywords = ['PRODUTO', 'DESCRICAO', 'ITEM', 'NOME'];

      for (var sheetName in excel.tables.keys) {
        final categoryName = sheetName.trim();
        if (categoryName.isEmpty) continue;

        final categoryId = await _getOrCreateCategory(
            categoryName, batch, categoryCache, onConflict);
        if (categoryId == null) continue;

        final sheet = excel.tables[sheetName]!;
        Map<int, String> activeHeader = {};
        int? activeProductColIndex;

        for (int rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
          final row = sheet.rows[rowIndex];
          if (row.isEmpty || row.every((c) => c?.value == null || c!.value.toString().trim().isEmpty)) continue;

          int productColCandidate = -1;
          bool hasPriceInRow = row.any((cell) {
            if (cell?.value == null) return false;
            final valueStr = cell?.value.toString().trim();
            return valueStr!.isNotEmpty && RegExp(r'^[\d\$\-R]').hasMatch(valueStr) && _parsePriceFromCell(cell) != null;
          });

          for (int i = 0; i < row.length; i++) {
            final cellValue = _removeDiacritics(row[i]?.value?.toString() ?? '').toUpperCase();
            if (productHeaderKeywords.any((keyword) => cellValue.contains(keyword))) {
              productColCandidate = i;
              break;
            }
          }

          if (productColCandidate != -1 && !hasPriceInRow) {
            activeHeader = {};
            for (int i = 0; i < row.length; i++) {
              if (row[i]?.value != null) activeHeader[i] = row[i]!.value.toString().trim();
            }
            activeProductColIndex = productColCandidate;
            continue;
          }

          if (activeHeader.isNotEmpty && activeProductColIndex != null && hasPriceInRow) {
            final productName = row.elementAtOrNull(activeProductColIndex)?.value?.toString().trim();
            if (productName == null || productName.isEmpty) continue;

            double? baseSalePrice, costPrice;
            final Map<String, dynamic> otherPrices = {};
            final Map<int, double> foundPrices = {};

            for (var h in activeHeader.entries) {
              final price = _parsePriceFromCell(row.elementAtOrNull(h.key));
              if (price != null) {
                foundPrices[h.key] = price;
                otherPrices[h.value] = price;
              }
            }

            if (foundPrices.isEmpty) continue;

            int? salePriceColIndex;
            final normalizedHeaders = { for (var e in activeHeader.entries) e.key: _removeDiacritics(e.value).toUpperCase() };

            for (var p in foundPrices.entries) {
              if (normalizedHeaders[p.key]!.contains('CUSTO')) { costPrice = p.value; break; }
            }
            for (var p in foundPrices.entries) {
              if (normalizedHeaders[p.key]!.contains('VENDA')) { salePriceColIndex = p.key; break; }
            }
            if (salePriceColIndex == null) {
              for (var p in foundPrices.entries) {
                if (normalizedHeaders[p.key]!.contains('ATE') || normalizedHeaders[p.key]!.contains('UNIT')) {
                  salePriceColIndex = p.key; break;
                }
              }
            }
            if (salePriceColIndex == null) {
              for (var p in foundPrices.entries) {
                if (!normalizedHeaders[p.key]!.contains('CUSTO')) {
                  salePriceColIndex = p.key; break;
                }
              }
            }
            salePriceColIndex ??= foundPrices.keys.first;
            baseSalePrice = foundPrices[salePriceColIndex];

            if (baseSalePrice != null) {
              final newProductRef = _firestore.collection('institutions').doc(institutionId).collection('products').doc();
              // *** DADOS SALVOS AGORA SÃO COMPATÍVEIS COM O MODELO ***
              batch.set(newProductRef, {
                'name': productName,
                'categoryId': categoryId,
                'salePrice': baseSalePrice,
                'costPrice': costPrice,
                'margin': null, // O modelo espera este campo
                'otherPrices': otherPrices, // O modelo agora espera este campo
              });
              totalProductsAdded++;
            }
          }
        }
      }

      if (totalProductsAdded > 0) {
        await batch.commit();
        return null; // Sucesso
      } else {
        return "Nenhum produto válido foi encontrado para importar no arquivo.";
      }
    } catch (e, s) {
      debugPrint("❌ ERRO CRÍTICO NA IMPORTAÇÃO: $e\n$s");
      return "Ocorreu um erro crítico ao processar o arquivo.";
    }
  }
}