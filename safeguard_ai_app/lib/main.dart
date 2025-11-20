import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const SafeGuardApp());
}

class SafeGuardApp extends StatelessWidget {
  const SafeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard AI — Sensor Demo',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const SensorHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SensorHomePage extends StatefulWidget {
  const SensorHomePage({super.key});
  @override
  State<SensorHomePage> createState() => _SensorHomePageState();
}

class _SensorHomePageState extends State<SensorHomePage> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _x = 0, _y = 0, _z = 0;
  String _status = 'Tap Start to read accelerometer';

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Most devices do not require an explicit permission for accelerometer,
    // but this requests sensor permission when available.
    await Permission.sensors.request();
  }

  void _startListening() async {
    setState(() => _status = 'Requesting permission...');
    await _requestPermissions();
    setState(() => _status = 'Listening...');
    // Use the non-deprecated API
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      setState(() {
        _x = event.x;
        _y = event.y;
        _z = event.z;
      });
    });
  }

  void _stopListening() {
    _accelSub?.cancel();
    _accelSub = null;
    setState(() => _status = 'Stopped');
  }

  double get _magnitude => math.sqrt(_x * _x + _y * _y + _z * _z);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SafeGuard AI — Sensor Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Accelerometer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('x: ${_x.toStringAsFixed(3)}'),
            Text('y: ${_y.toStringAsFixed(3)}'),
            Text('z: ${_z.toStringAsFixed(3)}'),
            const SizedBox(height: 8),
            Text('magnitude: ${_magnitude.toStringAsFixed(3)}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _accelSub == null ? _startListening : _stopListening,
              child: Text(_accelSub == null ? 'Start' : 'Stop'),
            ),
            const SizedBox(height: 24),
            const Text('Tip: Run on a real device for accurate sensor data.'),
          ],
        ),
      ),
    );
  }
}