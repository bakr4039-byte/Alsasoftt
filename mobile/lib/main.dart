import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/admin_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HaderApp());
}

class HaderApp extends StatelessWidget {
  const HaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حاضر',
      debugShowCheckedModeBanner: false,
      theme: buildHaderTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _StartupGate(),
    );
  }
}

/// يقرر شاشة البداية: تسجيل دخول جديد أو استكمال جلسة محفوظة — وإذا كانت الجلسة
/// محفوظة، يوجّه المستخدم لشاشة معلم أو لوحة إدارة حسب دوره.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _api = ApiService();
  bool _checking = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final hasToken = await _api.hasToken();
    if (!hasToken) {
      if (!mounted) return;
      setState(() {
        _destination = const LoginScreen();
        _checking = false;
      });
      return;
    }
    try {
      final profile = await _api.fetchMe();
      if (!mounted) return;
      setState(() {
        _destination = profile.role == 'teacher' ? const HomeScreen() : const AdminScreen();
        _checking = false;
      });
    } catch (_) {
      // التوكن المحفوظ صار غير صالح (مثلاً منتهي) — نرجع لشاشة الدخول.
      await _api.logout();
      if (!mounted) return;
      setState(() {
        _destination = const LoginScreen();
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _destination!;
  }
}
