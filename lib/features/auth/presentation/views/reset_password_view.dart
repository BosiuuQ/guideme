import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _sendResetCode() async {
    try {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wpisz e-mail")),
        );
        return;
      }

      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wysłano kod na e-mail")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: ${e.toString()}")),
      );
    }
  }

  Future<void> _submitNewPassword() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth
          .verifyOTP(
            type: OtpType.recovery,
            token: _codeController.text.trim(),
            email: _emailController.text.trim(),
          );

      if (response.user == null) {
        throw Exception("Kod jest niepoprawny lub wygasł.");
      }

      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hasło zostało zresetowane")),
      );
      context.go('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: ${e.toString()}")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Odzyskiwanie hasła")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "E-mail"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sendResetCode,
              child: const Text("Wyślij kod"),
            ),
            const Divider(height: 40),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: "Kod z e-maila"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Nowe hasło"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitNewPassword,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Zmień hasło"),
            )
          ],
        ),
      ),
    );
  }
}
