// lib/pages/legal/terms_of_use_page.dart
import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Termos de Uso'),
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
                  Icon(Icons.gavel_rounded, size: 48, color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    "CONTRATO DE LICENÇA DE USUÁRIO FINAL",
                    style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.outline,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Última atualização: Dezembro de 2025",
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),

            // --- CONTEÚDO LEGAL ---
            _TermSection(
              number: '1',
              title: 'ACEITE DOS TERMOS',
              content: 'Ao criar uma conta ou utilizar o aplicativo "Quadra Vendas", você concorda integralmente com estes termos. Se você estiver utilizando o aplicativo em nome de uma empresa (Pessoa Jurídica), você declara ter poderes para vincular a empresa a estes termos.',
            ),

            _TermSection(
              number: '2',
              title: 'LICENÇA DE USO E ACESSO',
              content: 'A Dequadra Soluções Digitais concede uma licença revogável, não exclusiva e intransferível para uso do software.\n\n'
                  '2.1. Administrador: O usuário pagante (Titular) detém o controle total da conta e dos dados.\n'
                  '2.2. Usuários Vinculados: Vendedores cadastrados pelo Administrador têm acesso limitado e revogável a qualquer momento pelo Titular.',
            ),

            _TermSection(
              number: '3',
              title: 'PLANOS E PAGAMENTOS',
              content: 'O serviço é prestado no modelo de assinatura pré-paga.\n\n'
                  '3.1. O não pagamento ou a expiração da licença resultará no bloqueio imediato do acesso às funcionalidades administrativas e financeiras.\n'
                  '3.2. Os dados serão preservados por um período de carência de 90 dias após o bloqueio. Após este período, a Dequadra reserva-se o direito de excluir dados de contas inativas.',
            ),

            _TermSection(
              number: '4',
              title: 'PROPRIEDADE DOS DADOS',
              content: 'Todos os dados de clientes, vendas e produtos inseridos no sistema são de propriedade exclusiva da Instituição Contratante (Administrador).\n\n'
                  '4.1. Vendedores não possuem direito de propriedade sobre a carteira de clientes cadastrada durante o uso da ferramenta corporativa.',
            ),

            _TermSection(
              number: '5',
              title: 'RESPONSABILIDADES E GARANTIAS',
              content: 'O software é fornecido "como está" (as is).\n\n'
                  '5.1. A Dequadra não se responsabiliza por:\n'
                  'a) Falhas de conectividade ou internet do usuário;\n'
                  'b) Lucros cessantes ou perda de oportunidades de negócios;\n'
                  'c) Erros operacionais causados por inserção incorreta de dados.',
            ),

            _TermSection(
              number: '6',
              title: 'PROPRIEDADE INTELECTUAL',
              content: 'É estritamente proibido:\n'
                  'a) Copiar, modificar ou criar obras derivadas do código-fonte;\n'
                  'b) Realizar engenharia reversa ou tentar acessar o banco de dados diretamente;\n'
                  'c) Vender, alugar ou sublicenciar o acesso ao software para terceiros não autorizados.',
            ),

            _TermSection(
              number: '7',
              title: 'DISPOSIÇÕES GERAIS',
              content: 'A Dequadra reserva-se o direito de atualizar estes termos periodicamente. O uso contínuo do serviço após as alterações constitui aceitação dos novos termos. O foro eleito para dirimir quaisquer dúvidas é o da Comarca de Pato Branco - PR.',
            ),

            const SizedBox(height: 32),

            // --- RODAPÉ ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "Dúvidas sobre os termos?",
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      // Ação de contato
                    },
                    child: Text(
                      "dequadraapps@gmail.com",
                      style: TextStyle(
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TermSection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _TermSection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número da Cláusula
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}