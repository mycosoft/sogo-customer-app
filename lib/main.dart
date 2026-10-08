import 'package:flutter/material.dart';
import 'core/app_services.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/location_gate.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SogoCustomerApp());
}

class SogoCustomerApp extends StatelessWidget {
  const SogoCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOGO Customer',
      navigatorKey: PushService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildSogoTheme(),
      home: const LocationGate(child: _RootGate()),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late final Future<String?> _tokenFuture = apiClient.loadToken();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        return snapshot.data == null ? const LoginScreen() : const AppShell();
      },
    );
  }
}
