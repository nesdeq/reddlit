import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reddlit/screens/user_profile_screen.dart';
import 'package:reddlit/services/request_pipeline.dart';
import 'package:reddlit/services/settings_provider.dart';

void main() {
  testWidgets('a failed post load offers retry under the profile header',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(
      () async {
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: const MaterialApp(home: UserProfileScreen(username: 'someone')),
        ));
        // User info dispatches first; the post page waits one pipeline gap.
        await tester.pump(RequestPipeline.minGap);
        await tester.pump(RequestPipeline.minGap);
        expect(find.text('Karma'), findsOneWidget);
        expect(find.text('No posts yet'), findsNothing);
        expect(find.text('Failed to load posts.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
      () => MockClient((_) async => http.Response('', 404)),
    );
  });
}
