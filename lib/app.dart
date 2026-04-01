import 'package:flutter/material.dart';
import 'package:setawalk/features/home/auth/auth_gate.dart';

class SetaWalkApp extends StatelessWidget {
  const SetaWalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SetaWalk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const AuthGate(),
    );
  }
}