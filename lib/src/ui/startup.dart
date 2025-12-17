// Startup / Onboarding flow — full file (complete, no truncation)
// - Pages: Start, Enable, LongPress, Shake, Done
// - Responsive wrapper to avoid overflow in landscape
// - Uses ManualTrigger (lib/src/manual_trigger.dart) and permission helper (lib/src/permission_and_start.dart)

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../manual_trigger.dart';
import '../permission_and_start.dart';
import 'home_scaffold.dart';

const kBgColor = Color(0xFFF0F3F6);
const kTitleColor = Color(0xFF1C2833);
const kBlue = Color(0xFF0096FB);
const kBlueEnd = Color(0xFF0064E0);
const kGrey = Color(0xFF677989);
const kWhite = Color(0xFFFCFCFD);
const kCTA = Color(0xFF0064E0);

// Slightly larger hero than before but still capped to avoid huge desktop rendering
const double _kMaxHeroImageWidth = 520.0;
const double _kHeroWidthFactor = 0.75;

/// Helper that builds a responsive page body which:
/// - expands to available height
/// - scrolls when the content doesn't fit (e.g. landscape / small screens)
Widget responsivePageBody(BuildContext context, Widget child) {
  return LayoutBuilder(builder: (context, constraints) {
    final availableHeight = constraints.maxHeight;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: availableHeight),
        child: IntrinsicHeight(child: child),
      ),
    );
  });
}

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  final PageController _pc = PageController();
  int _pageIndex = 0;

  void _goNext() {
    if (_pageIndex < 4) {
      _pc.animateToPage(_pageIndex + 1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      StartPage(onNext: _goNext),
      EnablePage(onNext: _goNext),
      LongPressPage(onNext: _goNext),
      ShakePage(onNext: _goNext),
      DonePage(onFinish: () {
        // Replace onboarding with the HomeScaffold when done
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScaffold()));
      }),
    ];

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/linear_back_color.png',
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
              ),
            ),
            PageView(
              controller: _pc,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: pages,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Pages ----------------

class StartPage extends StatelessWidget {
  final VoidCallback onNext;
  const StartPage({required this.onNext, super.key});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final imageWidth = math.min(screenW * _kHeroWidthFactor, _kMaxHeroImageWidth);
    final imageTopOffset = -imageWidth * 0.08;
    final imageRightOffset = -imageWidth * 0.12;

    return responsivePageBody(
      context,
      Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              top: imageTopOffset,
              right: imageRightOffset,
              child: SizedBox(
                width: imageWidth,
                child: Image.asset('assets/images/logo_start.png', fit: BoxFit.contain),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aware your',
                        style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: kTitleColor)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Safety ', style: GoogleFonts.poppins(fontSize: 53, fontWeight: FontWeight.w800, color: kBlue)),
                        TextSpan(text: 'first', style: GoogleFonts.poppins(fontSize: 53, fontWeight: FontWeight.w800, color: kTitleColor)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCTA,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Get Started', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: kWhite)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18, color: kWhite),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EnablePage extends StatelessWidget {
  final VoidCallback onNext;
  const EnablePage({required this.onNext, super.key});

  Future<void> _onEnablePressed(BuildContext context) async {
    final ok = await requestMicrophonePermission();
    // If permission prompt already accepted previously, the OS dialog won't appear.
    // We still show a small confirmation and proceed.
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission granted')));
      onNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return responsivePageBody(
      context,
      Container(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(child: Image.asset('assets/images/logo_with_text.png', height: 32)),
            const SizedBox(height: 22),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Automatic ', style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: kBlue)),
                TextSpan(text: 'it', style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: kTitleColor)),
              ]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Clicking below button', style: GoogleFonts.poppins(fontSize: 14, color: kGrey)),
            const SizedBox(height: 24),
            Expanded(child: Center(child: Image.asset('assets/images/ear_pic_enable.png', width: 220, fit: BoxFit.contain))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 28),
              child: ElevatedButton(
                onPressed: () => _onEnablePressed(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCTA,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: Text('Enable', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: kWhite)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LongPressPage extends StatefulWidget {
  final VoidCallback onNext;
  const LongPressPage({required this.onNext, super.key});
  @override
  State<LongPressPage> createState() => _LongPressPageState();
}

class _LongPressPageState extends State<LongPressPage> with TickerProviderStateMixin {
  static const int requiredHoldSeconds = 5;
  Timer? _timer;
  int _elapsed = 0;
  late AnimationController _ringController;
  late ManualTrigger _manualTrigger;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    // ManualTrigger now expects onTriggered: (String method)
    _manualTrigger = ManualTrigger(onTriggered: _onManualTriggered);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringController.dispose();
    _manualTrigger.dispose();
    super.dispose();
  }

  // Update the handler to accept the method string.
  // ManualTrigger will call onTriggered('long_press') for programmatic long-press
  void _onManualTriggered(String method) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirmed')));
    // If you want different behavior depending on method:
    // if (method == 'long_press') { ... } else if (method == 'shake') { ... }
  }

  // Start the hold timer
  void _startHold() {
    _elapsed = 0;
    _ringController.forward(from: 0.0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _elapsed++;
      });
      if (_elapsed >= requiredHoldSeconds) {
        t.cancel();
        // trigger the manual trigger (this will do haptic feedback and call onTriggered)
        _manualTrigger.fireTrigger();
        // small delay to allow feedback/show snack before navigation
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onNext();
        });
      }
    });
  }

  // Cancel the hold timer
  void _cancelHold() {
    _timer?.cancel();
    _ringController.stop();
    setState(() {
      _elapsed = 0;
    });
  }

  void _handleTapDown(TapDownDetails details) => _startHold();
  void _handleTapUp(TapUpDetails details) => _cancelHold();
  void _handleTapCancel() => _cancelHold();

  Widget _buildLayeredBoxes() {
    return SizedBox(
      width: 360,
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(56),
              gradient: LinearGradient(colors: [kBlue.withOpacity(0.12), kBlueEnd.withOpacity(0.12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              gradient: LinearGradient(colors: [kBlue.withOpacity(0.18), kBlueEnd.withOpacity(0.18)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(36), color: kCTA),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Image.asset('assets/images/long_press_pic.png', fit: BoxFit.contain),
            ),
          ),
          SizedBox(
            width: 400,
            height: 400,
            child: AnimatedBuilder(
              animation: _ringController,
              builder: (c, w) {
                return CustomPaint(
                  painter: _RingPainter(progress: _ringController.value, color: kBlue),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return responsivePageBody(
      context,
      Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Image.asset('assets/images/logo_with_text.png', height: 32),
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: 'Long Press ', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: kBlue)),
                  TextSpan(text: 'it', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: kTitleColor)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Hold in 5s', style: GoogleFonts.poppins(fontSize: 16, color: kGrey)),
            const SizedBox(height: 28),
            Expanded(child: Center(child: _buildLayeredBoxes())),
            Padding(
              padding: const EdgeInsets.only(bottom: 36.0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 60),
                  decoration: BoxDecoration(
                    color: kCTA,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: Text('Hold to confirm', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kWhite)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 8.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide / 2) - stroke;
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fgPaint = Paint()
      ..shader = LinearGradient(colors: [kBlue, kBlueEnd]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class ShakePage extends StatefulWidget {
  final VoidCallback onNext;
  const ShakePage({required this.onNext, super.key});

  @override
  State<ShakePage> createState() => _ShakePageState();
}

class _ShakePageState extends State<ShakePage> {
  bool _listening = false;
  late ManualTrigger _manualTrigger;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _manualTrigger = ManualTrigger(onTriggered: _onTriggered);
    _manualTrigger.startListening();
  }

  @override
  void dispose() {
    _manualTrigger.dispose();
    super.dispose();
  }

    // Update the onTriggered to accept the method parameter
  void _onTriggered(String method) {
    // ManualTrigger will call this with 'shake' when shake is detected,
    // or 'long_press' if fireTrigger() was used.
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _status = 'Shake detected';
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shake detected')));
  }
  
  void _toggleListening() {
    setState(() {
      _listening = !_listening;
    });
    if (_listening) {
      _manualTrigger.startListening();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started shake listening')));
    } else {
      _manualTrigger.stopListening();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stopped shake listening')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return responsivePageBody(
      context,
      Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(children: [
          const SizedBox(height: 36),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Image.asset('assets/images/logo_with_text.png', height: 32),
            ),
          ),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: 'Shake ', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: kBlue)),
                TextSpan(text: 'it to trigger', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: kTitleColor)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Start shake listening to enable gesture detection', style: GoogleFonts.poppins(fontSize: 14, color: kGrey)),
          const SizedBox(height: 36),
          Expanded(
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kBlue.withOpacity(0.15), kBlueEnd.withOpacity(0.15)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(child: Image.asset('assets/images/shake_pic.png', width: 200)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _toggleListening,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _listening ? kBlueEnd : kCTA, minimumSize: const Size.fromHeight(52)),
                  child: Text(_listening ? 'Stop shake listening' : 'Start shake listening',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kWhite)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(backgroundColor: kCTA, minimumSize: const Size.fromHeight(52)),
                  child: Text('Next', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kWhite)),
                ),
              ],
            ),
          )
        ]),
      ),
    );
  }
}

class DonePage extends StatelessWidget {
  final VoidCallback onFinish;
  const DonePage({required this.onFinish, super.key});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final imageWidth = math.min(screenW * _kHeroWidthFactor, _kMaxHeroImageWidth);

    return responsivePageBody(
      context,
      Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              top: -imageWidth * 0.08,
              right: -imageWidth * 0.12,
              child: SizedBox(
                width: imageWidth,
                child: Image.asset('assets/images/logo_start.png', fit: BoxFit.contain),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Safety',
                        style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: kTitleColor)),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: screenW * 0.75),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('We care now',
                            style: GoogleFonts.poppins(fontSize: 53, fontWeight: FontWeight.w800, color: kBlue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: onFinish,
                      style: ElevatedButton.styleFrom(backgroundColor: kCTA, minimumSize: const Size.fromHeight(56)),
                      child: Text('Launch', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kWhite)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}