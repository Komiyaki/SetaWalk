import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: String.fromEnvironment('supabaseUrl'),
    anonKey: String.fromEnvironment('supabaseAnonKey'),
  );
  runApp(const SetaWalkApp());
}

final supbase = Supabase.instance.client;