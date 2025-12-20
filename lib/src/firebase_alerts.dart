// url=https://github.com/CasperTarc/SafeGuard-AI/blob/main/lib/src/firebase_alerts.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart'; // to read Firebase.app().options

/// Write an alert record to Firestore 'alerts' collection and verify the write.
/// - type: "fall" | "scream" | "inactivity" | "long_press" | "shake"
/// - trigger: "auto" | "manual"
/// - outcome: "sent" | "cancelled" | "timeout"
Future<void> writeAlertToFirestore({
  required String type,
  required String trigger,
  required String outcome,
  Map<String, dynamic>? extra,
}) async {
  try {
    // DEBUG: which Firebase app/project are we using?
    try {
      final app = Firebase.app();
      final proj = app.options.projectId ?? '<no-project-id>';
      final appId = app.options.appId ?? '<no-app-id>';
      if (kDebugMode) debugPrint('DEBUG: Firebase app name=${app.name} projectId=$proj appId=$appId');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Firebase.app() not available (not initialized?): $e');
    }

    final now = DateTime.now().toLocal();
    final humanTs = DateFormat('yyyy-MM-dd EEE h:mma').format(now);

    final data = <String, dynamic>{
      'type': type,
      'trigger': trigger,
      'outcome': outcome,
      'humanTimestamp': humanTs,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (extra != null) data.addAll(extra);

    // Attempt the write and capture the returned DocumentReference
    final docRef = await FirebaseFirestore.instance.collection('alerts').add(data);

    if (kDebugMode) debugPrint('Alert write initiated: doc=${docRef.id} data=$data');

    // Optional: try to read back the document to confirm it exists (may not show serverTimestamp immediately)
    try {
      final snap = await docRef.get();
      if (snap.exists) {
        if (kDebugMode) debugPrint('Alert readback success: doc=${docRef.id} -> ${snap.data()}');
      } else {
        if (kDebugMode) debugPrint('Alert readback: document does not exist immediately for doc=${docRef.id} (server timestamp may still be pending)');
      }
    } catch (readErr, st) {
      if (kDebugMode) debugPrint('Alert readback failed for doc=${docRef.id}: $readErr\n$st');
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('writeAlertToFirestore error: $e\n$st');
    rethrow; // rethrow so the caller can surface or log the error too
  }
}