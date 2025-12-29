// lib/services/subscription.service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Definição das Regras (Hardcoded para segurança)
class PlanRules {
  static const Map<String, dynamic> limits = {
    'START': {
      'max_nfs': 0, // Não emite
      'allow_financial': false,
      'allow_whatsapp': false,
      'price_extra_nf': 0.0,
    },
    'CONTROL': {
      'max_nfs': 50,
      'allow_financial': true,
      'allow_whatsapp': false, // Só pago a parte
      'price_extra_nf': 2.50,
    },
    'PERFORMANCE': {
      'max_nfs': 200,
      'allow_financial': true,
      'allow_whatsapp': false, // Só pago a parte
      'price_extra_nf': 1.90,
    },
    'ELITE': {
      'max_nfs': 1000,
      'allow_financial': true,
      'allow_whatsapp': true, // Incluso
      'price_extra_nf': 1.00,
    },
  };
}

class SubscriptionService {
  final Map<String, dynamic> institutionData;

  SubscriptionService(this.institutionData);

  // Qual o plano atual?
  String get currentPlan => (institutionData['plan'] ?? 'START').toString().toUpperCase();

  // Obtém os limites do plano atual
  Map<String, dynamic> get _myLimits => PlanRules.limits[currentPlan] ?? PlanRules.limits['START']!;

  // === PERMISSÕES DE ACESSO (Ocultar/Mostrar Botões) ===

  bool get canAccessFinancial => _myLimits['allow_financial'] ?? false;

  bool get canAccessWhatsappAuto => _myLimits['allow_whatsapp'] ?? false;

  bool get canAccessFinancialModule {
    return ['CONTROL', 'PERFORMANCE', 'ELITE'].contains(currentPlan);
  }

  // === REGRAS DE CONSUMO (Lógica de Bloqueio/Aviso) ===

  /// Verifica se pode emitir NF.
  /// Retorna um objeto com status e mensagem.
  PlanCheckResult checkNfeEmission() {
    // 1. Se for START, bloqueia total
    if (_myLimits['max_nfs'] == 0) {
      return PlanCheckResult(
          allowed: false,
          message: 'Seu plano Start não permite emissão fiscal. Faça um upgrade!',
          requiresUpgrade: true
      );
    }

    // 2. Verifica consumo
    int used = institutionData['features_usage']?['nfs_emitted'] ?? 0;
    int limit = _myLimits['max_nfs'];

    if (used >= limit) {
      // Aqui você decide: Bloqueia ou Deixa passar cobrando?
      // Pela nossa estratégia, deixamos passar avisando do custo.
      double price = _myLimits['price_extra_nf'];
      return PlanCheckResult(
          allowed: true,
          isOverLimit: true,
          message: 'Você excedeu sua franquia de $limit notas. Esta emissão custará R\$ $price na próxima fatura.'
      );
    }

    return PlanCheckResult(allowed: true);
  }
}

class PlanCheckResult {
  final bool allowed;
  final bool isOverLimit;
  final bool requiresUpgrade;
  final String? message;

  PlanCheckResult({
    required this.allowed,
    this.isOverLimit = false,
    this.requiresUpgrade = false,
    this.message
  });
}