import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:safeguard_ai/src/fall_detector.dart';

String _fmtElapsed(Duration d) {
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

// ANSI color
String _color(String text, int code) => '\x1B[${code}m$text\x1B[0m';
String tagDebug(String t) => _color('[$t]', 31); // red
String tagImpact(String t) => _color('[$t]', 32); // green
String tagConfirmed(String t) => _color('[$t]', 35); // purple
String tagInfo(String t) => _color('[$t]', 36); // blue
String tagTime(String t) => _color('[$t]', 33); // yellow for elapsed

// Format timestamp
String friendlyTimestamp(DateTime dt) {
  final local = dt.toLocal();
  return DateFormat('yyyy-MM-dd EEE h:mma').format(local);
}

void main() {
  test(
    'Testing fall_detector.dart logic by having 1st impact, and another strong 2nd impact (at 3s)',
    () async {
      final detector = FallDetector(
        inactivityWindow: const Duration(seconds: 8),
        minTimeBetweenFalls: Duration.zero,
        debug: true,
      );

      final start = DateTime.now();
      String elapsed() => _fmtElapsed(DateTime.now().difference(start));

      // Debug stream (red)
      final debugSub = detector.debugStream.listen((m) {
        // Confirmed message (purple) or normal debug (red)
        if (m.startsWith('[confirmed]')) {
          print('');
          final rest = m.substring('[confirmed]'.length).trim();
          print(
            '${tagTime('[' + elapsed() + ']')} ${tagConfirmed('confirmed')} $rest',
          );
        } else {
          print('${tagTime('[' + elapsed() + ']')} ${tagDebug('debug')} $m');
        }
      });

      // Impact stream (green)
      final impacts = <ImpactEvent>[];
      final impactSub = detector.impactStream.listen((ev) {
        impacts.add(ev);
        print(
          '${tagTime('[' + elapsed() + ']')} ${tagImpact('impact')} peak=${ev.peakMagnitude.toStringAsFixed(2)} at ${friendlyTimestamp(ev.timestamp)}',
        );
      });

      // Confirmed fall (purple)
      DateTime? confirmedAt;
      final confirmCompleter = Completer<DateTime?>();
      final fallSub = detector.fallStream.listen((ts) {
        confirmedAt = ts;
        if (!confirmCompleter.isCompleted) confirmCompleter.complete(ts);
      });

      try {
        // Info (blue)
        print(
          '${tagTime('[' + elapsed() + ']')} ${tagInfo('info')} Test start: insert first (1st) impact at t=0',
        );
        detector.addSample(detector.impactThreshold + 1.0, DateTime.now());

        // Wait real 3 seconds
        await Future<void>.delayed(const Duration(seconds: 3));

        // Insert second spike and message
        print(
          '\n${tagTime('[' + elapsed() + ']')} ${tagInfo('info')} Insert new impact spike (2nd): Recalculate the time again...',
        );
        detector.addSample(detector.impactThreshold + 2.0, DateTime.now());

        // Wait for confirmed fall (should be ~3s + 8s = ~11s). Allow up to 15s total for safety.
        await confirmCompleter.future.timeout(const Duration(seconds: 15));

        // Small delay to ensure prints flush
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assertions
        expect(
          confirmedAt,
          isNotNull,
          reason: 'Detector should have emitted a confirmed fall',
        );
        expect(
          impacts.length >= 2,
          true,
          reason:
              'Expected at least two ImpactEvent emissions (initial + new spike). Found ${impacts.length}.',
        );
      } on TimeoutException {
        fail('Timed out waiting for confirmed fall (expected within ~15s)');
      } finally {
        await debugSub.cancel();
        await impactSub.cancel();
        await fallSub.cancel();
        detector.dispose();
      }
    },
    timeout: Timeout(Duration(seconds: 40)),
  );
}
