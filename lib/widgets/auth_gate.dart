import 'package:material_ui/material_ui.dart';
import '../services/auth_service.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted || _showing) return;
    if (AuthService.instance.needsLogin) {
      _showing = true;
      Login.start(context).whenComplete(() => _showing = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
