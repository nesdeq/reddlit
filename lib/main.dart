import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final (font, license) in AppTheme.fontLicenses) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString(license));
    }
  });
  await AuthService.instance.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const ReddlitApp(),
    ),
  );
}

class ReddlitApp extends StatelessWidget {
  const ReddlitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Reddlit',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 320),
          themeAnimationCurve: Curves.easeOutCubic,
          debugShowCheckedModeBanner: false,
          home: const AuthGate(child: HomeScreen()),
        );
      },
    );
  }
}
