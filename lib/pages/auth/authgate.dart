// lib/pages/auth/authgate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quadra_vendas/pages/expiredLicense/expired-license.page.dart';
import 'package:quadra_vendas/pages/home/home-page.dart';
import 'package:quadra_vendas/pages/login/login-page.dart';
// Importe a sua nova tela de Admin
import 'package:quadra_vendas/pages/superAdmin/manage-institutions.page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Se o utilizador não está logado
        if (!authSnapshot.hasData) {
          return const LoginPage();
        }

        final user = authSnapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userDocSnapshot) {

            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
            final userStatus = userData['status'];
            final role = userData['role']; // Capturamos o role

            // 1. SEGURANÇA GLOBAL: Verifica se está ativo
            if (userStatus == 'inactive') {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            // 2. ROTEAMENTO DE SUPER ADMIN (Novo)
            // Se for super_admin, vai direto para a gestão, sem checar licença ou institutionId
            if (role == 'super_admin') {
              return const ManageInstitutionsPage();
            }

            // 3. ROTEAMENTO PADRÃO (Admin de empresa ou Employee)
            final institutionId = userData['institutionId'];

            if (institutionId == null) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Erro: Conta sem instituição vinculada.'),
                  ),
                ),
              );
            }

            // Verifica a licença da instituição
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('institutions').doc(institutionId).get(),
              builder: (context, institutionDocSnapshot) {

                if (institutionDocSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (!institutionDocSnapshot.hasData || !institutionDocSnapshot.data!.exists) {
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                final institutionData = institutionDocSnapshot.data!.data() as Map<String, dynamic>;

                // Tratamento seguro para timestamp (pode vir nulo em cadastros manuais errados)
                final Timestamp? licenseTimestamp = institutionData['licenseExpiresAt'] as Timestamp?;

                if (licenseTimestamp != null && licenseTimestamp.toDate().isBefore(DateTime.now())) {
                  return const ExpiredLicensePage();
                }

                // Acesso permitido
                return const HomePage();
              },
            );
          },
        );
      },
    );
  }
}