import 'package:flutter/material.dart';

/// Serviço centralizado de mensagens do AgroMarkt.
class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline,
      background: Colors.green.shade700,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.error_outline,
      background: Theme.of(context).colorScheme.error,
    );
  }

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.warning_amber_rounded,
      background: Colors.orange.shade800,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      background: Theme.of(context).colorScheme.primary,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color background,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Converte erros técnicos em mensagens compreensíveis.
  /// Não apresenta detalhes internos do servidor ao usuário.
  static String friendlyError(
    Object error, {
    String fallback = 'Não foi possível concluir a operação. Tente novamente.',
  }) {
    final message = error.toString().toLowerCase();

    if (message.contains('timeout') ||
        message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed to fetch') ||
        message.contains('networkerror') ||
        message.contains('connection refused') ||
        message.contains('xmlhttprequest')) {
      return 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
    }

    if (message.contains('401') ||
        message.contains('token de autenticação') ||
        message.contains('sessão inválida')) {
      return 'Sua sessão expirou ou os dados de acesso são inválidos. Entre novamente.';
    }

    if (message.contains('403')) {
      return 'Você não tem permissão para realizar esta operação.';
    }

    if (message.contains('404')) {
      return 'O registro solicitado não foi encontrado.';
    }

    if (message.contains('409')) {
      return 'Esta operação não pode ser realizada porque existe um conflito nos dados.';
    }

    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504')) {
      return 'O servidor está temporariamente indisponível. Tente novamente mais tarde.';
    }

    return fallback;
  }
}
