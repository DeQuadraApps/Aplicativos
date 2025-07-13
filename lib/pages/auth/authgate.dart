import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/pages/createInstitution/create-institution.page.dart';
import 'package:quadra_vendas/pages/expiredLicense/expired-license.page.dart';
import 'package:quadra_vendas/pages/home/home-page.dart';
// Importe suas páginas
import 'package:quadra_vendas/pages/login/login-page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. ESTE STREAM OUVE A MUDANÇA DE LOGIN/LOGOUT
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Se o usuário não está logado, mostra a tela de login
        if (!authSnapshot.hasData) {
          return const LoginPage();
        }

        // Se o usuário ESTÁ logado, obtemos o objeto User
        final user = authSnapshot.data!;

        // 2. ESTE NOVO STREAM OUVE AS MUDANÇAS NO DOCUMENTO DO USUÁRIO NO FIRESTORE
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userDocSnapshot) {

            // Enquanto os dados do usuário carregam, mostramos um loader
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Se o documento do usuário não existe, algo deu muito errado. Deslogamos.
            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
              // Esta verificação é crucial para o onboarding.
              // Se o doc não existe, o fluxo de cadastro ainda não o criou.
              // O ideal é que o cadastro crie o doc com institutionId: null
              // Para ser seguro, mostramos o loader até que o doc seja criado.
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
            final institutionId = userData['institutionId'];

            // 3. A LÓGICA DE DECISÃO AGORA ESTÁ AQUI, DENTRO DO STREAM DO USUÁRIO

            // Se não há ID de instituição, o usuário precisa passar pelo onboarding
            if (institutionId == null || (institutionId is String && institutionId.isEmpty)) {
              return const CreateInstitutionPage();
            }

            // Se há um ID, verificamos a licença da instituição (usando um FutureBuilder para a instituição)
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('institutions').doc(institutionId).get(),
              builder: (context, institutionDocSnapshot) {

                if (institutionDocSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (!institutionDocSnapshot.hasData || !institutionDocSnapshot.data!.exists) {
                  // A instituição do usuário foi deletada. Deslogar por segurança.
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                final institutionData = institutionDocSnapshot.data!.data() as Map<String, dynamic>;
                final licenseExpiresAt = institutionData['licenseExpiresAt'] as Timestamp;

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