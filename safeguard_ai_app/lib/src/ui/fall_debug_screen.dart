// Debug screen to test FallDetector + SensorService on a real device.
// When a confirmed fall occurs we show the confirmation overlay via showConfirmationDialog(context).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fall_detector.dart';
import '../sensor_service.dart';
import 'widgets.dart';
import 'confirmation.dart'; // provides showConfirmationDialog
import 'confirmation.dart' as _confirmation;

class FallDebugScreen extends StatefulWidget {
  const FallDebugScreen({super.key});

  @override
  State<FallDebugScreen> createState() => _FallDebugScreenState();
}

class _FallDebugScreenState extends State<FallDebugScreen> {
  late final FallDetector _fallDetector;
  late final SensorService _sensorService;
  final List<String> _logs = [];
  StreamSubscription<DateTime>? _fallSub;
  StreamSubscription<String>? _debugSub;

  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();

    // Create detector with debug enabled so its debugStream will emit human-readable messages.
    _fallDetector = FallDetector(debug: true);

    // Listen to debug messages from FallDetector
    _debugSub = _fallDetector.debugStream.listen((m) => _addLog('[FD] $m'));

    // Listen for confirmed fall events and show the confirmation overlay
    _fallSub = _fallDetector.fallStream.listen((dt) async {
      _addLog('[FD] FALL CONFIRMED at $dt');
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
      if (mounted) {
        showConfirmationDialog(context);
      }
    });

    // Create sensor service, forwarding debug and onSample to UI
    _sensorService = SensorService(
      fallDetector: _fallDetector,
      sampleMs: 40,
      lowPassAlpha: 0.90,
      onDebug: (m) => _addLog('[SS] $m'),
      onSample: (mag, ts) => _addLog('[SS] sample=${mag.toStringAsFixed(2)} @ ${ts.toIso8601String()}'),
    );
  }

  @override
  void dispose() {
    _fallSub?.cancel();
    _debugSub?.cancel();
    _sensorService.dispose();
    _fallDetector.dispose();
    super.dispose();
  }

  void _addLog(String line) {
    // Keep logs manageable
    setState(() {
      _logs.insert(0, '${DateTime.now().toIso8601String()}  $line');
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
  }

  void _startService() {
    if (_serviceRunning) return;
    _sensor_service_start();
    setState(() => _serviceRunning = true);
    _addLog('[UI] SensorService started');
  }

  void _stopService() {
    if (!_serviceRunning) return;
    _sensorService.stop();
    setState(() => _serviceRunning = false);
    _addLog('[UI] SensorService stopped');
  }

  // Programmatically simulate a confirmed fall.
  void _simulateConfirmedFall() {
    _addLog('[UI] Simulating confirmed fall (impact + inactivity)');

    final fd = _fallDetector;
    final now = DateTime.now();

    final impactValue = fd.impactThreshold + 6.0; // above threshold
    fd.addSample(impactValue, now);
    _addLog('[UI] Simulated impact sample=${impactValue.toStringAsFixed(2)}');

    final inactivityMs = fd.inactivityWindow.inMilliseconds;
    final stepMs = 200;
    int elapsed = 0;
    Timer.periodic(Duration(milliseconds: stepMs), (t) {
      elapsed += stepMs;
      fd.addSample(0.0, DateTime.now());
      if (elapsed >= inactivityMs + 200) {
        t.cancel();
        _addLog('[UI] Finished inactivity simulation (elapsed=${elapsed}ms)');
      }
    });
  }

  // extra safe start wrapper (to avoid tight ui calls)
  void _sensor_service_start() {
    try {
      _sensorService.start();
    } catch (e) {
      _addLog('[UI] SensorService start error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Detector — Debug'),
        backgroundColor: kBlue,
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _serviceRunning ? null : _startService,
                  style: ElevatedButton.styleFrom(backgroundColor: kBlue),
                  child: const Text('Start'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _serviceRunning ? _stopService : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _simulateConfirmedFall,
                  child: const Text('Simulate Fall'),
                ),
                const Spacer(),
                Text(_serviceRunning ? 'Running' : 'Stopped', style: TextStyle(color: _serviceRunning ? Colors.green : Colors.red)),
              ],
            ),
          ),

          // Logs / status
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12)),
              child: _logs.isEmpty
                  ? Center(child: Text('No logs yet. Press Start then Simulate Fall.', style: GoogleFonts.poppins(color: kGrey)))
                  : ListView.builder(
                      reverse: true,
                      itemCount: _logs.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Text(_logs[i], style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}