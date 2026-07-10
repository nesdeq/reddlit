import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/auth_service.dart';

class LoginWebViewSheet extends StatefulWidget {
  const LoginWebViewSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.95,
          child: LoginWebViewSheet(),
        ),
      );

  @override
  State<LoginWebViewSheet> createState() => _LoginWebViewSheetState();
}

class _LoginWebViewSheetState extends State<LoginWebViewSheet> {
  bool _handling = false;

  Future<void> _capture() async {
    if (_handling || !mounted) return;
    final cookies = await CookieManager.instance()
        .getCookies(url: WebUri('https://www.reddit.com/'));
    final hasSession = cookies.any(
      (c) => c.name == 'reddit_session' && '${c.value}'.isNotEmpty,
    );
    if (!hasSession) return;
    _handling = true;

    const keep = {'reddit_session', 'token_v2', 'loid', 'edgebucket', 'csv'};
    final header = cookies
        .where((c) => keep.contains(c.name) && '${c.value}'.isNotEmpty)
        .map((c) => '${c.name}=${c.value}')
        .join('; ');

    final error = await AuthService.instance.setSession(header);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      _handling = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Log in to Reddit'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: InAppWebView(
          initialUrlRequest:
              URLRequest(url: WebUri('https://www.reddit.com/login/')),
          onLoadStop: (controller, url) => _capture(),
          onUpdateVisitedHistory: (controller, url, isReload) => _capture(),
        ),
      ),
    );
  }
}
