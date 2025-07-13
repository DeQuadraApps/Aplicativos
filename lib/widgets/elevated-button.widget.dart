// lib/widgets/shadow_button.dart

import 'package:flutter/material.dart';

class ShadowButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const ShadowButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Acede ao tema atual para obter as cores corretas
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final buttonStyle = theme.elevatedButtonTheme.style;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            // A cor da sombra agora vem do tema ativo
            color: colorScheme.primary.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5), // Posição da sombra
          ),
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            // A cor do indicador de progresso agora é a mesma cor do texto do botão
            color: buttonStyle?.foregroundColor?.resolve({}),
            strokeWidth: 3,
          ),
        )
            : Text(text),
      ),
    );
  }
}
