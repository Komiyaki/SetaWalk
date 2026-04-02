import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'package:setawalk/shared/constants/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('SUPABASE URL EMPTY: ${Env.supabaseUrl.isEmpty}');
  print('SUPABASE URL: ${Env.supabaseUrl}');

  print('SUPABASE ANON KEY EMPTY: ${Env.supabaseAnonKey.isEmpty}');
  print('SUPABASE ANON KEY: ${Env.supabaseAnonKey}');

  print('GOOGLE MAPS API KEY EMPTY: ${Env.googleMapsApiKey.isEmpty}');
  print('GOOGLE MAPS API KEY: ${Env.googleMapsApiKey}');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const SetaWalkApp());
}

final supabase = Supabase.instance.client;