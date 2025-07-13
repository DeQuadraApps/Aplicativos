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
            const SizedBox(height: 16),
            const Text(
              'Estes Termos e Condições de Uso ("Termos") regem o seu acesso e uso da aplicação Quadra Vendas ("Software"), desenvolvido por Dequadra Apps. Ao criar uma conta e utilizar o nosso Software, você concorda em cumprir integralmente com estes Termos.',
            ),

            const SizedBox(height: 24),
            Text('1. Licença de Uso', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              '1.1. Concedemos a você uma licença limitada, não exclusiva, intransferível e revogável para usar o Software para fins comerciais internos, de acordo com o plano contratado.\n\n'
                  '1.2. É estritamente proibido compartilhar, sublicenciar, vender, alugar, ou de qualquer outra forma distribuir o seu acesso ao Software para terceiros. Cada conta é individual e vinculada à sua instituição.',
            ),

            const SizedBox(height: 24),
            Text('2. Duração e Expiração da Licença', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              '2.1. O seu acesso ao Software é condicionado pela validade da sua licença, que possui uma data de expiração definida no momento da contratação ou renovação.\n\n'
                  '2.2. Ao atingir a data de expiração, o seu acesso e o de todos os utilizadores da sua instituição ao Software serão automaticamente suspensos. Todos os dados permanecerão guardados, mas inacessíveis.\n\n'
                  '2.3. O acesso só será restabelecido após a confirmação do pagamento referente à renovação da licença, com um prazo médio de 1 (um) dia útil para a reativação do sistema. Não haverá acesso parcial ou temporário sem a devida regularização financeira.',
            ),

            const SizedBox(height: 24),
            Text('3. Propriedade Intelectual', style: textTheme.titleLarge),
            const Divider(),
            const Text(
              'O Software, incluindo o seu código, design, e marca "Quadra Vendas", é propriedade exclusiva da Dequadra Apps. Estes Termos não lhe concedem quaisquer direitos sobre a nossa propriedade intelectual, exceto a licença de uso limitada.',
            ),

            const SizedBox(height: 24),
            Text('4. Modificações dos Termos', style: textTheme.titleLarge),
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
