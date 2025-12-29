// lib/enums/plan_type.enum.dart

enum PlanType {
  start,
  performance,
  elite;

  /// Converte a String do Firebase (ex: 'performance') para o Enum
  static PlanType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'performance':
        return PlanType.performance;
      case 'elite':
        return PlanType.elite;
      case 'start':
      default:
        return PlanType.start; // Padrão seguro se vier nulo ou errado
    }
  }

  /// Helper para saber se o plano tem recursos visuais Premium (PDF Colorido)
  bool get isPro => this != PlanType.start;

  /// Helper para exibir o nome bonito na tela
  String get label {
    switch (this) {
      case PlanType.start:
        return 'Start';
      case PlanType.performance:
        return 'Performance';
      case PlanType.elite:
        return 'Elite';
    }
  }
}