import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/url_utils.dart';

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => const LoginSheet(),
      );

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _cookie = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cookie.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthService.instance.submitSessionCookie(_cookie.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final dividerBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: BorderSide(color: colors.dividerColor),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge),
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spacing5),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect your Reddit session',
                style: colors.theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                "Reddit gates password login behind a captcha, so paste the "
                "session from a browser you're already signed in to.",
                style: colors.theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing3),
              _StepList(colors: colors),
              const SizedBox(height: AppTheme.spacing3),
              TextField(
                controller: _cookie,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'reddit_session value',
                  filled: true,
                  fillColor: colors.backgroundColor,
                  border: dividerBorder,
                  enabledBorder: dividerBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(color: colors.accentColor, width: 2),
                  ),
                ),
                style: colors.theme.textTheme.bodyMedium,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppTheme.spacing3),
                Text(
                  _error!,
                  style: colors.theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacing4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Connect'),
                ),
              ),
              const SizedBox(height: AppTheme.spacing2),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () =>
                      UrlUtils.openUrl('https://old.reddit.com/login/'),
                  child: Text(
                    'Open Reddit login in browser',
                    style: TextStyle(color: colors.accentColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final ThemeHelper colors;
  const _StepList({required this.colors});

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Sign in to reddit.com in any browser.',
      'Open DevTools → Application → Cookies → reddit.com.',
      'Copy the value of the reddit_session cookie.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
            child: Text(
              '${i + 1}.  ${steps[i]}',
              style: colors.theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
