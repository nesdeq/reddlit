import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'login_sheet.dart';
import 'login_webview_sheet.dart';

class Login {
  const Login._();

  static bool get webViewSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static Future<void> start(BuildContext context) => webViewSupported
      ? LoginWebViewSheet.show(context)
      : LoginSheet.show(context);
}
