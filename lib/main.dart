// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quadra_vendas/firebase_options.dart';
import 'package:quadra_vendas/pages/auth/authgate.dart';
import 'package:quadra_vendas/providers/theme.provider.dart';
// Corrigi o nome do import para seguir o padrão de nomes de ficheiro
import 'package:quadra_vendas/themes/app.theme.dart';

Future<void> main() async {
  // Garante que o Flutter e o Firebase estão prontos
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ==========================================================
  // O PROVIDER É INJETADO AQUI, NO TOPO DE TUDO
  // ==========================================================
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // O MATERIALAPP AGORA "OUVE" AS MUDANÇAS DO PROVIDER
    // ==========================================================
    // Usamos 'watch' para que este widget seja reconstruído sempre que o tema mudar.
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Quadra Vendas',
      debugShowCheckedModeBanner: false,

      // Configuração de Tema Dinâmica
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode, // O tema ativo vem do nosso Provider

      // Configuração de Localização (para o DatePicker)
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],

      home: AuthGate(),
    );
  }
}
