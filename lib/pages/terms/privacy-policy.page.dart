// lib/pages/legal/privacy_policy_page.dart
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CABEÇALHO ---
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.privacy_tip_rounded, size: 40, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "SUA PRIVACIDADE É IMPORTANTE",
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.outline,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Esta política descreve como a Dequadra coleta, usa e protege seus dados.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Vigência: Dezembro de 2025",
                    style: textTheme.labelSmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),

            // --- SEÇÕES DETALHADAS ---

            _PrivacySection(
              icon: Icons.folder_shared_outlined,
              title: '1. DADOS QUE COLETAMOS',
              content: 'Para fornecer nossos serviços, coletamos as seguintes categorias de informações:\n\n'
                  '• Dados Cadastrais: Nome completo, e-mail, telefone e informações da empresa (como nome fantasia e endereço).\n'
                  '• Dados Operacionais: Informações sobre produtos, vendas, clientes e metas inseridos no sistema para o funcionamento da ferramenta.\n'
                  '• Dados de Uso: Logs de acesso, tipo de dispositivo, sistema operacional e relatórios de erros para manutenção do sistema.',
            ),

            _PrivacySection(
              icon: Icons.settings_suggest_outlined,
              title: '2. COMO USAMOS SEUS DADOS',
              content: 'Utilizamos as informações coletadas para as seguintes finalidades:\n\n'
                  '• Prestação do Serviço: Autenticar seu acesso, processar suas vendas e gerar relatórios gerenciais.\n'
                  '• Comunicação: Enviar avisos sobre o status da licença, atualizações de segurança ou suporte técnico.\n'
                  '• Melhoria do Produto: Analisar como o aplicativo é utilizado para desenvolver novas funcionalidades e corrigir falhas.\n'
                  '• Segurança: Prevenir fraudes, atividades ilegais e garantir a integridade da sua conta.',
            ),

            _PrivacySection(
              icon: Icons.share_outlined,
              title: '3. COMPARTILHAMENTO DE DADOS',
              content: 'A Dequadra NÃO vende seus dados pessoais para terceiros. O compartilhamento ocorre apenas nas seguintes situações estritas:\n\n'
                  '• Infraestrutura Tecnológica: Servidores de nuvem (ex: Google Cloud/Firebase) necessários para hospedar o banco de dados do aplicativo.\n'
                  '• Obrigação Legal: Quando exigido por lei, ordem judicial ou autoridade governamental competente.',
            ),

            _PrivacySection(
              icon: Icons.lock_outline,
              title: '4. SEGURANÇA E ARMAZENAMENTO',
              content: 'Adotamos medidas técnicas robustas para proteger seus dados, incluindo criptografia em trânsito (SSL/TLS) e controles de acesso rigorosos.\n\n'
                  'Seus dados são armazenados em servidores seguros. Embora nos esforcemos para garantir a segurança absoluta, nenhum sistema é completamente imune a ataques cibernéticos.',
            ),

            _PrivacySection(
              icon: Icons.gavel_outlined,
              title: '5. SEUS DIREITOS (LGPD)',
              content: 'Como titular dos dados, você possui os seguintes direitos garantidos pela Lei Geral de Proteção de Dados:\n\n'
                  '• Acesso: Solicitar uma cópia dos seus dados armazenados.\n'
                  '• Retificação: Corrigir dados incompletos ou desatualizados.\n'
                  '• Exclusão: Solicitar a exclusão da sua conta e dados associados.\n'
                  '• Revogação: Retirar seu consentimento para tratamentos específicos a qualquer momento.',
            ),

            _PrivacySection(
              icon: Icons.delete_forever_outlined,
              title: '6. EXCLUSÃO DE CONTA',
              content: 'Para solicitar a exclusão definitiva da sua conta e de todos os dados associados, entre em contato exclusivamente através de nossos canais de suporte (e-mail ou WhatsApp).\n\n'
                  'Após a validação da titularidade, os dados serão inativados imediatamente e excluídos permanentemente de nossos backups em até 90 dias.',
            ),

            const SizedBox(height: 24),

            // --- RODAPÉ DE CONTATO (DPO) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mail_outline, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        "Encarregado de Dados (DPO)",
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Para exercer seus direitos, solicitar exclusão ou tirar dúvidas:",
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      // Lógica para abrir e-mail
                    },
                    child: Text(
                      "dequadraapps@gmail.com",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                "Quadra Vendas © 2025\nPato Branco, PR - Brasil",
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET AUXILIAR ---

class _PrivacySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28.0), // Alinhado com o texto do título
            child: Text(
              content,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}