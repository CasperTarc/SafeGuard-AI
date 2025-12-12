import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

// Write an alert record to Firestore 'alerts' collection.
//
// - type: "fall" | "scream" | "inactivity" | "long_press" | "shake" 
// - trigger: "auto" | "manual"
// - outcome: "sent" | "cancelled" | "timeout"
Future<void> writeAlertToFirestore({
  required String type,
  required String trigger,
  required String outcome,
  Map<String, dynamic>? extra,
}) async {
  try {
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

    await FirebaseFirestore.instance.collection('alerts').add(data);

    if (kDebugMode) debugPrint('Alert written to Firestore: $data');
  } catch (e, st) {
    if (kDebugMode) debugPrint('writeAlertToFirestore error: $e\n$st');
  }
}