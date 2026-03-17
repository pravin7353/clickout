import 'package:flutter/foundation.dart';
// Web ke liye html import (Sirf web par compile hoga)
import 'package:universal_html/html.dart' as html;
import '../../utils/user_session.dart';

class StoreEntryService {
  // 🚀 WEB APP INTERCEPTOR (URL Catching)
  static bool checkWebEntryUrl() {
    if (!kIsWeb) return false; // Agar mobile app hai toh bypass karo

    try {
      String currentUrl = html.window.location.href;
      Uri uri = Uri.parse(currentUrl);

      // Check agar URL me fentry parameters hain
      if (uri.queryParameters.containsKey('t') &&
          uri.queryParameters.containsKey('s')) {
        String tenant = uri.queryParameters['t']!;
        String store = uri.queryParameters['s']!;
        String branch = uri.queryParameters['b'] ?? '';

        // 🧠 SAAS INJECTION IN MEMORY
        UserSession.setStoreContext(
          tId: tenant,
          sId: store,
          bCode: branch,
        );

        // Security: URL ko clean kar do taaki user copy na kar sake
        html.window.history.pushState(null, 'ClickOut', '/home');
        return true; // Successfully entered a store
      }
    } catch (e) {
      debugPrint("Web URL Routing Error: $e");
    }
    return false;
  }

  // 📱 MOBILE APP PARSER (QR Scanner Catching)
  static bool parseScannedQR(String scannedData) {
    try {
      Uri uri = Uri.parse(scannedData);

      if (uri.queryParameters.containsKey('t') &&
          uri.queryParameters.containsKey('s')) {
        UserSession.setStoreContext(
          tId: uri.queryParameters['t']!,
          sId: uri.queryParameters['s']!,
          bCode: uri.queryParameters['b'] ?? '',
        );
        return true;
      }
    } catch (e) {
      debugPrint("Invalid QR Format");
    }
    return false;
  }
}
