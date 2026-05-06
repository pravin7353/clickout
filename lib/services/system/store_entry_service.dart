import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      // Check agar URL me entry parameters hain
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

        // 🚀 🔥 FIX FOR WEB: Update Firestore directly from URL entry!
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          debugPrint(
              "🔥 WEB ENTRY: Forcing update for lastVisit on ${user.uid}");
          FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'lastVisit': FieldValue.serverTimestamp(),
            'branchCode': branch,
            'tenantId': tenant,
            'tenantIds': FieldValue.arrayUnion([tenant]),
            'storeVisits': {
              tenant: {
                'lastVisit': FieldValue.serverTimestamp(),
                'branchCode': branch,
              }
            }
          }, SetOptions(merge: true)).then((_) {
            debugPrint("✅ SUCCESS: Web lastVisit updated in Firestore!");
          }).catchError((e) {
            debugPrint("🚨 ERROR: Web Firestore update failed - $e");
          });
        }

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
        // 1. Local memory update
        UserSession.setStoreContext(
          tId: uri.queryParameters['t']!,
          sId: uri.queryParameters['s']!,
          bCode: uri.queryParameters['b'] ?? '',
        );

        // 🚀 2. FIREBASE UPDATE (Using Set with Merge to bypass update failures)
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          debugPrint(
              "🔥 QR SCANNED: Forcing update for lastVisit on ${user.uid}");

          String tenant = uri.queryParameters['t']!;
          String branch = uri.queryParameters['b'] ?? '';

          FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'lastVisit': FieldValue.serverTimestamp(),
            'branchCode': branch,
            'tenantId': tenant,
            'tenantIds': FieldValue.arrayUnion([tenant]),
            'storeVisits': {
              tenant: {
                'lastVisit': FieldValue.serverTimestamp(),
                'branchCode': branch,
              }
            }
          }, SetOptions(merge: true)).then((_) {
            debugPrint(
                "✅ SUCCESS: lastVisit successfully written to Firestore!");
          }).catchError((e) {
            debugPrint("🚨 ERROR: Firestore set failed - $e");
          });
        } else {
          debugPrint(
              "🚨 ERROR: App thinks user is not logged in during QR scan!");
        }

        return true;
      }
    } catch (e) {
      debugPrint("🚨 ERROR: Invalid QR Format: $e");
    }
    return false;
  }
}
