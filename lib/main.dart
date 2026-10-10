import 'package:flutter/material.dart';
import 'core/app_services.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/location_gate.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
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
  bool _ready = false;
  bool _onboarded = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var onboarded = false;
    String? token;
    try {
      onboarded = await OnboardingScreen.isDone();
    } catch (_) {}
    try {
      token = await apiClient.loadToken();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _onboarded = onboarded;
      _token = token;
      _ready = true;
    });
  }

  /// Continue immediately from local state — the onboarding flag is only
  /// persisted best-effort, so storage problems can never trap the user.
  void _finishOnboarding() {
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();
    if (!_onboarded) {
      return OnboardingScreen(onDone: _finishOnboarding);
    }
    return _token == null ? const LoginScreen() : const AppShell();
  }
}
