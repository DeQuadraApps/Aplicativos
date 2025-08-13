// lib/services/product-import.service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

    final collectionRef = _firestore.collection('institutions').doc(institutionId).collection('productCategories');
    final query = await collectionRef.where('name', isEqualTo: trimmedName).limit(1).get();

    if (query.docs.isNotEmpty) {
      final existingCategoryId = query.docs.first.id;
      final action = await onConflict(trimmedName);

      switch (action) {
        case CategoryImportAction.overwrite:
          final productsSnapshot = await _firestore
              .collection('institutions').doc(institutionId)
              .collection('products').where('categoryId', isEqualTo: existingCategoryId)
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
        default:
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
    if (cell == null || cell.value == null) return null;
    final String valueAsString = cell.value.toString().trim();
    if (valueAsString.isEmpty) return null;

    String processedString = valueAsString;
    // Lida com formatos de moeda como "R$ 2,50"
    processedString = processedString.replaceAll('R\$', '').trim();

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

  Future<String?> importFromExcel({
    required CategoryConflictResolver onConflict,
    required String adminId,
  }) async {
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

        final categoryId = await _getOrCreateCategory(categoryName, batch, categoryCache, onConflict);
        if (categoryId == null) continue;

        final sheet = excel.tables[sheetName]!;
        if (sheet.rows.isEmpty) continue;

        int headerRowIndex = -1;
        int productColIndex = -1;
        Map<int, String> headerMap = {};

        for (int i = 0; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          for (int j = 0; j < row.length; j++) {
            final cellValue = _removeDiacritics(row[j]?.value?.toString() ?? '').toUpperCase();
            if (productHeaderKeywords.any((keyword) => cellValue.contains(keyword))) {
              headerRowIndex = i;
              productColIndex = j;
              break;
            }
          }
          if (headerRowIndex != -1) break;
        }

        if (headerRowIndex == -1) {
          debugPrint("Aviso: Nenhum cabeçalho de produto encontrado na aba '$categoryName'.");
          continue;
        }

        final headerRow = sheet.rows[headerRowIndex];
        for (int i = 0; i < headerRow.length; i++) {
          if (headerRow[i]?.value != null) {
            headerMap[i] = headerRow[i]!.value.toString().trim();
          }
        }

        for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final productName = row.elementAtOrNull(productColIndex)?.value?.toString().trim();

          if (productName == null || productName.isEmpty) continue;

          double? baseSalePrice, costPrice;
          final Map<String, dynamic> otherPrices = {};

          // +++ LÓGICA DE CORREÇÃO +++
          // Itera sobre os cabeçalhos, mas IGNORA a coluna do produto ao procurar preços.
          for (var headerEntry in headerMap.entries) {
            final colIdx = headerEntry.key;
            final headerText = headerEntry.value;

            // Pula a coluna do produto
            if (colIdx == productColIndex) continue;

            final price = _parsePriceFromCell(row.elementAtOrNull(colIdx));
            if (price != null) {
              otherPrices[headerText] = price;
            }
          }

          if (otherPrices.isEmpty) {
            debugPrint("Aviso: Produto '$productName' na aba '$categoryName' não tem preços válidos e foi ignorado.");
            continue;
          }

          final normalizedHeaders = { for (var e in otherPrices.entries) e.key.toUpperCase(): e.value };

          String? salePriceKey;
          String? costPriceKey;

          for(var key in normalizedHeaders.keys){
            if(_removeDiacritics(key).contains('CUSTO')) costPriceKey = key;
            if(_removeDiacritics(key).contains('VENDA') || _removeDiacritics(key).contains('UNIT')) salePriceKey = key;
          }

          costPrice = costPriceKey != null ? normalizedHeaders[costPriceKey] : null;
          salePriceKey ??= normalizedHeaders.keys.firstWhere((k) => k != costPriceKey, orElse: () => normalizedHeaders.keys.first);
          baseSalePrice = normalizedHeaders[salePriceKey];


          if (baseSalePrice != null) {
            final newProductRef = _firestore.collection('institutions').doc(institutionId).collection('products').doc();
            batch.set(newProductRef, {
              'name': productName,
              'categoryId': categoryId,
              'categoryName': categoryName,
              'salePrice': baseSalePrice,
              'costPrice': costPrice,
              'margin': null,
              'otherPrices': otherPrices,
              'createdBy': adminId,
            });
            totalProductsAdded++;
          }
        }
      }

      if (totalProductsAdded > 0) {
        await batch.commit();
        return null; // Sucesso
      } else {
        return "Nenhum produto válido foi encontrado para importar. Verifique se as abas do seu arquivo Excel contêm uma coluna de cabeçalho com a palavra 'Produto' e linhas de dados abaixo dela.";
      }
    } catch (e, s) {
      debugPrint("❌ ERRO CRÍTICO NA IMPORTAÇÃO: $e\n$s");
      if (e is FirebaseException && e.code == 'permission-denied') {
        return "Permissão negada. Verifique as regras de segurança do Firestore.";
      }
      return "Ocorreu um erro crítico ao processar o arquivo.";
    }
  }
}