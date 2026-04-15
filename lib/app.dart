import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:setawalk/features/home/auth/auth_gate.dart';
import 'package:setawalk/features/home/auth/set_new_password_page.dart';

class SetaWalkApp extends StatefulWidget {
  const SetaWalkApp({super.key});

  @override
  State<SetaWalkApp> createState() => _SetaWalkAppState();
}

class _SetaWalkAppState extends State<SetaWalkApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const SetNewPasswordPage(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SetaWalk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2C2C2C),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(64),
          ),
          elevation: 6,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 80,
            vertical: 100,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}