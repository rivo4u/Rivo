import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

// Client-side publishable credentials are safe to ship with a mobile app
// when database RLS and Auth policies are correctly configured.
const supabaseUrl = 'https://ucldwvgaisbekvuekgel.supabase.co';
const supabasePublishableKey = 'sb_publishable_1jfDyWJjWNqEByQWZi9JPw_9ITKtePn';

// This is the Google WEB OAuth client ID configured as Supabase's server client.
// Android still needs its own OAuth client/SHA-1 configuration in Google Cloud.
const googleWebClientId = '1039684501316-tucgdpv1d16lr3nmmthe2dv9bibhk6a3.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  await GoogleSignIn.instance.initialize(
    serverClientId: googleWebClientId,
  );

  runApp(const RivoApp());
}

class RivoApp extends StatelessWidget {
  const RivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
