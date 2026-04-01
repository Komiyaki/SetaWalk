import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

const supabaseUrl = String.fromEnvironment('supabaseUrl');
const supabaseAnonKey = String.fromEnvironment('supabaseAnonKey');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('SUPABASE URL: $supabaseUrl');
  print('SUPABASE ANON KEY EMPTY: ${supabaseAnonKey.isEmpty}');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const SetaWalkApp());
}

final supabase = Supabase.instance.client;