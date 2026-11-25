import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reddlit/screens/settings_screen.dart';
import 'package:reddlit/services/settings_provider.dart';

void main() {
  testWidgets('theme sheet lists System, Light, Dark and applies the pick',
      (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    // Settings load through the secure-storage channel, which answers only on
    // real event-loop turns.
    final settings = (await tester.runAsync(() async {
      final s = SettingsProvider();
      await s.ready;
      return s;
    }))!;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: const MaterialApp(home: SettingsScreen()),
    ));

    await tester.ensureVisible(find.text('Theme'));
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final options = [
      for (final tile in tester.widgetList<ListTile>(
          find.descendant(of: sheet, matching: find.byType(ListTile))))
        ((tile.title! as Text).data!, tile.trailing != null),
    ];
    expect(options, [('System', false), ('Light', true), ('Dark', false)]);

    await tester.tap(find.descendant(of: sheet, matching: find.text('Dark')));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);

    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.scrollUntilVisible(
      find.text('ABOUT'),
      viewportHeight,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reddlit'), findsOneWidget);
    expect(find.textContaining('Version'), findsNothing);
  });
}
