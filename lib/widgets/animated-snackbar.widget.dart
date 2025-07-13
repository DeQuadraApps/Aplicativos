// lib/utils/app_snack_bar.dart

import 'package:animated_snack_bar/animated_snack_bar.dart';
import 'package:flutter/material.dart';

/// Uma classe helper para exibir SnackBars customizados e animados.
///
/// Fornece métodos estáticos para os tipos mais comuns de notificações:
/// sucesso, erro, aviso (warning) e informação.
class AppSnackBar {
  // Tornamos o construtor privado para que a classe não possa ser instanciada.
  AppSnackBar._();

  /// Exibe uma SnackBar de sucesso.
  ///
  /// [context] O BuildContext da árvore de widgets.
  /// [message] O texto a ser exibido na SnackBar.
  /// [duration] A duração opcional da SnackBar (padrão: 3 segundos).
  static void showSuccess(
      BuildContext context, {
        required String message,
        Duration duration = const Duration(seconds: 3),
      }) {
    AnimatedSnackBar.material(
      message,
      type: AnimatedSnackBarType.success,
      duration: duration,
      mobileSnackBarPosition: MobileSnackBarPosition.bottom, // Posição em telas mobile
      desktopSnackBarPosition: DesktopSnackBarPosition.topRight, // Posição em telas desktop
    ).show(context);
  }

  /// Exibe uma SnackBar de erro.
  static void showError(
      BuildContext context, {
        required String message,
        Duration duration = const Duration(seconds: 3),
      }) {
    AnimatedSnackBar.material(
      message,
      type: AnimatedSnackBarType.error,
      duration: duration,
      mobileSnackBarPosition: MobileSnackBarPosition.bottom,
      desktopSnackBarPosition: DesktopSnackBarPosition.topRight,
    ).show(context);
  }

  /// Exibe uma SnackBar de aviso (warning).
  static void showWarning(
      BuildContext context, {
        required String message,
        Duration duration = const Duration(seconds: 3),
      }) {
    AnimatedSnackBar.material(
      message,
      type: AnimatedSnackBarType.warning,
      duration: duration,
      mobileSnackBarPosition: MobileSnackBarPosition.bottom,
      desktopSnackBarPosition: DesktopSnackBarPosition.topRight,
    ).show(context);
  }

  /// Exibe uma SnackBar de informação.
  static void showInfo(
      BuildContext context, {
        required String message,
        Duration duration = const Duration(seconds: 3),
      }) {
    AnimatedSnackBar.material(
      message,
      type: AnimatedSnackBarType.info,
      duration: duration,
      mobileSnackBarPosition: MobileSnackBarPosition.bottom,
      desktopSnackBarPosition: DesktopSnackBarPosition.topRight,
    ).show(context);
  }
}