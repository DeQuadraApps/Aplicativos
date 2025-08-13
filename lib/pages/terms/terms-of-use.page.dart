// lib/pages/legal/terms_of_use_page.dart
import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos e Condições de Uso'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Termos de Uso - Quadra Vendas', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text("Última atualização: 06 de Agosto de 2025"), // É uma boa prática adicionar a data da última atualização
            const SizedBox(height: 16),
            const Text(
              'Estes Termos e Condições de Uso ("Termos") regem o seu acesso e uso da aplicação Quadra Vendas ("Software"), desenvolvido por Dequadra Apps. Ao criar uma conta e utilizar o nosso Software, você concorda em cumprir integralmente com estes Termos.',
            ),

            const SizedBox(height: 24),
            Text('1. Definição de Papéis', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              '1.1. Administrador: O utilizador inicial que cria a conta da Instituição é designado como "Administrador". Este utilizador tem controle total sobre a gestão da conta, incluindo a capacidade de criar, visualizar e desativar contas de Vendedor, bem como aceder a todos os dados da instituição (clientes, produtos, vendas, metas e relatórios).\n\n'
                  '1.2. Vendedor: Uma conta de utilizador criada por um Administrador é designada como "Vendedor" (ou "employee"). Os Vendedores têm acesso limitado ao Software, restrito à gestão dos seus próprios clientes e vendas, e ao catálogo de produtos da instituição, conforme definido por estes Termos.',
            ),

            const SizedBox(height: 24),
            Text('2. Licença e Gestão de Contas', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              '2.1. Concedemos à Instituição uma licença limitada, não exclusiva e intransferível para usar o Software para fins comerciais internos, de acordo com o plano contratado.\n\n'
                  '2.2. O Administrador é o único responsável pela criação e gestão das contas dos Vendedores vinculados à sua Instituição. É estritamente proibido compartilhar, sublicenciar, vender ou alugar o acesso ao Software. Cada conta é individual e intransferível.',
            ),

            const SizedBox(height: 24),
            Text('3. Duração e Expiração da Licença', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              '3.1. O acesso ao Software por parte de todos os utilizadores (Administrador e Vendedores) é condicionado pela validade da licença da Instituição.\n\n'
                  '3.2. Ao atingir a data de expiração, o acesso de todos os utilizadores será automaticamente suspenso. Os dados permanecerão guardados, mas inacessíveis, até à renovação da licença.\n\n'
                  '3.3. O acesso só será restabelecido após a confirmação do pagamento referente à renovação, com um prazo médio de 1 (um) dia útil para a reativação do sistema.',
            ),

            const SizedBox(height: 24),
            Text('4. Propriedade dos Dados', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              '4.1. Todos os dados inseridos no Software, incluindo informações de clientes, produtos e vendas, são de propriedade da Instituição representada pelo Administrador.\n\n'
                  '4.2. O Vendedor reconhece que os dados de clientes e vendas por ele registados pertencem à Instituição e podem ser acedidos, geridos e transferidos pelo Administrador.',
            ),

            const SizedBox(height: 24),
            Text('5. Propriedade Intelectual', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              'O Software, incluindo o seu código, design, e marca "Quadra Vendas", é propriedade exclusiva da Dequadra Apps. Estes Termos não lhe concedem quaisquer direitos sobre a nossa propriedade intelectual, exceto a licença de uso limitada.',
            ),

            const SizedBox(height: 24),
            Text('6. Modificações dos Termos', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              'Reservamo-nos o direito de modificar estes Termos a qualquer momento. Notificaremos sobre alterações significativas. O uso continuado do Software após as alterações constitui a sua aceitação dos novos Termos.',
            ),
          ],
        ),
      ),
    );
  }
}