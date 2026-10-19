import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

const Color _kBlue = Color(0xFF2F5BFF);
const Color _kInk = Color(0xFF1A1230);
const Color _kCream = Color(0xFFFFF6E3);
const Color _kYellow = Color(0xFFFFD60A);
const Color _kLime = Color(0xFFB8F400);

double _rad(double deg) => deg * math.pi / 180;

List<BoxShadow> _hardShadow([double d = 4]) =>
    [BoxShadow(color: _kInk, offset: Offset(d, d), blurRadius: 0)];

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  Timer? _progressTimer;

  double _progress = 0.08;
  int _tipIndex = 0;

  static const List<String> _loadingTips = [
    'Warming up the party decks...',
    'Calibrating forehead tilt sensors...',
    'Shuffling movies, animals & food cards...',
    'Polishing neo-brutalist stickers...',
    "Let's Go!",
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _startLoadingSequence();
  }

  void _startLoadingSequence() {
    const stepDuration = Duration(milliseconds: 240);
    final rng = math.Random();

    _progressTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) return;

      setState(() {
        _progress += 0.12 + (rng.nextDouble() * 0.09);
        if (_progress >= 1.0) {
          _progress = 1.0;
          _tipIndex = _loadingTips.length - 1;
          timer.cancel();
          _navigateToHome();
        } else {
          _tipIndex = (_progress * (_loadingTips.length - 1)).floor();
        }
      });
    });
  }

  void _navigateToHome() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  /// Renders crisp 3D neo-brutalist outlined & shadowed display text
  Widget _outlinedHeroTitle() {
    final baseStyle = GoogleFonts.bowlbyOne(
      fontSize: 66,
      height: 0.95,
      letterSpacing: -1.0,
    );

    return Transform.rotate(
      angle: _rad(-4.5),
      child: Stack(
        children: [
          // Deep Ink Hard Offset Block Shadow
          Transform.translate(
            offset: const Offset(5, 6),
            child: Text(
              'Cipher!',
              style: baseStyle.copyWith(color: _kInk),
            ),
          ),
          // Crisp Ink Stroke Outline
          Text(
            'Cipher!',
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..color = _kInk,
            ),
          ),
          // Cream Foreground Fill
          Text(
            'Cipher!',
            style: baseStyle.copyWith(color: _kCream),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).round();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBlue,
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Top-Left Yellow Square Star Sticker
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  final dy = math.sin(_floatController.value * math.pi) * -7;
                  return Positioned(
                    top: 36 + dy,
                    left: 28,
                    child: child!,
                  );
                },
                child: Transform.rotate(
                  angle: _rad(-9),
                  child: Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kYellow,
                      border: Border.all(color: _kInk, width: 3),
                      boxShadow: _hardShadow(4),
                    ),
                    child: const Icon(Icons.star_rounded, color: _kInk, size: 32),
                  ),
                ),
              ),

              // 2. Top-Right Lime "PARTY READY" Rectangular Sticker
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  final dy = math.cos(_floatController.value * math.pi) * -7;
                  return Positioned(
                    top: 72 + dy,
                    right: 24,
                    child: child!,
                  );
                },
                child: Transform.rotate(
                  angle: _rad(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kLime,
                      border: Border.all(color: _kInk, width: 3),
                      boxShadow: _hardShadow(4),
                    ),
                    child: Text(
                      'PARTY READY',
                      style: GoogleFonts.bowlbyOne(
                        fontSize: 13,
                        color: _kInk,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Lower-Left Cream Square Star Sticker (Positioned cleanly above text)
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  final dy = math.cos(_floatController.value * math.pi) * 6;
                  return Positioned(
                    bottom: 175 + dy,
                    left: 38,
                    child: child!,
                  );
                },
                child: Transform.rotate(
                  angle: _rad(11),
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kCream,
                      border: Border.all(color: _kInk, width: 3),
                      boxShadow: _hardShadow(4),
                    ),
                    child: const Icon(Icons.star_rounded, color: _kInk, size: 28),
                  ),
                ),
              ),

              // 4. Main Foreground Layout
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Center Branding Stack
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _outlinedHeroTitle(),
                          const SizedBox(height: 22),

                          // Cream "FOREHEAD CHARADES" Rectangular Sticker
                          Transform.rotate(
                            angle: _rad(1.5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 9),
                              decoration: BoxDecoration(
                                color: _kCream,
                                border: Border.all(color: _kInk, width: 3),
                                boxShadow: _hardShadow(4),
                              ),
                              child: Text(
                                'FOREHEAD CHARADES',
                                style: GoogleFonts.bowlbyOne(
                                  fontSize: 14,
                                  color: _kInk,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Yellow "ACT • GUESS • LAUGH" Rectangular Sticker
                          Transform.rotate(
                            angle: _rad(-1.8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 9),
                              decoration: BoxDecoration(
                                color: _kYellow,
                                border: Border.all(color: _kInk, width: 3),
                                boxShadow: _hardShadow(4),
                              ),
                              child: Text(
                                'ACT • GUESS • LAUGH',
                                style: GoogleFonts.bowlbyOne(
                                  fontSize: 14,
                                  color: _kInk,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 4),

                    // Bottom Subway Surfers Style Loading Bar
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Loading Tip
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _loadingTips[_tipIndex],
                            key: ValueKey<int>(_tipIndex),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kCream,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Progress Track
                        Container(
                          height: 36,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _kCream,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: _kInk, width: 3.5),
                            boxShadow: _hardShadow(5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final fillWidth =
                                    (constraints.maxWidth * _progress)
                                        .clamp(0.0, constraints.maxWidth);
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width: fillWidth,
                                    height: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: _kLime,
                                      border: Border(
                                        right: BorderSide(
                                            color: _kInk, width: 3.5),
                                      ),
                                    ),
                                    child: CustomPaint(
                                      painter: _CandyStripePainter(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Outlined 92% Counter
                        Stack(
                          children: [
                            Transform.translate(
                              offset: const Offset(3, 3),
                              child: Text(
                                '$percent%',
                                style: GoogleFonts.bowlbyOne(
                                  fontSize: 28,
                                  color: _kInk,
                                ),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 28,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 4
                                  ..color = _kInk,
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 28,
                                color: _kCream,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandyStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF98CC00)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    const double step = 28;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
