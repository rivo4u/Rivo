import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;
  String? error;

  Future<void> _google() async {
    setState(() { loading = true; error = null; });
    try {
      final signIn = GoogleSignIn.instance;
      final account = await signIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Google ID token missing.');

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 20),
                Text('Rivo', style: AppTextStyles.heading(size: 34, color: AppColors.greenDarker)),
                const SizedBox(height: 8),
                Text('Voice rooms. Friends. Moments.', style: AppTextStyles.body(size: 14, color: AppColors.textMute)),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _google,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(loading ? 'Connecting…' : 'Continue with Google'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.greenDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Text(error!, textAlign: TextAlign.center, style: AppTextStyles.label(color: Colors.red.shade700)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
