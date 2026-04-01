import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool isLogin = true;
  bool keepSignedIn = false;
  bool loading = false;

  final supabase = Supabase.instance.client;

  Future<void> handleAuth() async {
    setState(() => loading = true);

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        if (passwordController.text != confirmController.text) {
          throw Exception("Passwords do not match");
        }

        await supabase.auth.signUp(
          email: emailController.text,
          password: passwordController.text,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => loading = false);
  }

  Future<void> resetPassword() async {
    await supabase.auth.resetPasswordForEmail(emailController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password reset email sent")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 60),

            /// 🔥 LOTTIE
            Lottie.asset('assets/lottie/login.json', height: 200),

            const SizedBox(height: 20),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            if (!isLogin)
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Confirm Password"),
              ),

            Row(
              children: [
                Checkbox(
                  value: keepSignedIn,
                  onChanged: (val) {
                    setState(() => keepSignedIn = val ?? false);
                  },
                ),
                const Text("Keep me signed in")
              ],
            ),

            ElevatedButton(
              onPressed: loading ? null : handleAuth,
              child: Text(isLogin ? "Login" : "Sign Up"),
            ),

            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin
                  ? "Don't have an account? Sign up"
                  : "Already have an account? Login"),
            ),

            if (isLogin)
              TextButton(
                onPressed: resetPassword,
                child: const Text("Forgot Password?"),
              ),
          ],
        ),
      ),
    );
  }
}