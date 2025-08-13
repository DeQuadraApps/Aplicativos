// lib/pages/auth/authgate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/pages/expiredLicense/expired-license.page.dart';
import 'package:quadra_vendas/pages/home/home-page.dart';
import 'package:quadra_vendas/pages/login/login-page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Se o utilizador não está logado, mostra a tela de login
        if (!authSnapshot.hasData) {
          return const LoginPage();
        }

        // Se o utilizador ESTÁ logado, obtemos o objeto User
        final user = authSnapshot.data!;

        // Usamos um FutureBuilder para obter os dados do utilizador UMA VEZ.
        // Isto é mais estável para a lógica de redirecionamento do que um Stream.
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userDocSnapshot) {

            // Enquanto os dados do utilizador carregam, mostramos um loader.
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Se o documento do utilizador não existe, algo correu mal ou o registo não terminou.
            // Para ser seguro, deslogamos o utilizador para que ele possa tentar novamente.
            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
              // Isto previne o loop infinito se o documento ainda não foi criado.
              // O ideal é que o utilizador tente fazer login novamente após um segundo.
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
            final institutionId = userData['institutionId'];
            final userStatus = userData['status'];

            // VERIFICAÇÃO DE SEGURANÇA: Se o utilizador foi desativado
            if (userStatus == 'inactive') {
              // Se o utilizador estiver inativo, desloga-o e não o deixa prosseguir.
              FirebaseAuth.instance.signOut();
              // A tela de login já mostra a mensagem de erro apropriada.
              return const LoginPage();
            }

            // Se o utilizador não tem uma instituição vinculada, isto é um estado de erro.
            // O fluxo de registo do admin DEVE criar a instituição.
            if (institutionId == null) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Erro de configuração: A sua conta não está vinculada a nenhuma instituição. Por favor, contacte o suporte.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            // Se há um ID de instituição, verificamos a licença
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('institutions').doc(institutionId).get(),
              builder: (context, institutionDocSnapshot) {

                if (institutionDocSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (!institutionDocSnapshot.hasData || !institutionDocSnapshot.data!.exists) {
                  // A instituição do utilizador foi eliminada. Deslogar por segurança.
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                final institutionData = institutionDocSnapshot.data!.data() as Map<String, dynamic>;
                final licenseExpiresAt = institutionData['licenseExpiresAt'] as Timestamp;

                // Verifica se a licença expirou
                if (licenseExpiresAt.toDate().isBefore(DateTime.now())) {
                  return const ExpiredLicensePage();
                }

                // Se tudo estiver OK, finalmente, acesso à HomePage!
                return const HomePage();
              },
            );
          },
        );
      },
    );
  }
}