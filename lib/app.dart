import 'package:flutter/material.dart';

import 'features/home/home_page.dart';

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
      home: const HomePage(),
    );
  }
}
