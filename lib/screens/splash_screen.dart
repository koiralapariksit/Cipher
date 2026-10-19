import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/deck_colors.dart';
import 'home_screen.dart';

/// Neo-Brutalist Arcade Subway-Surfers Style Loading SplashScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bobbingController;
  late final AnimationController _stripeController;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  static const List<String> _statusTips = [
    'Warming up the party decks...',
    'Calibrating forehead tilt sensors...',
    'Shuffling movies, animals & food cards...',
    "Let's Go!",
  ];

  @override
  void initState() {
    super.initState();

    // Gentle bobbing for floating stickers
    _bobbingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Infinite scrolling for diagonal candy stripes
    _stripeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    // Smooth arcade progress loading bar (2.2s)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder: (context, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });

    _progressController.forward();
  }

  @override
  void dispose() {
    _bobbingController.dispose();
    _stripeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  String _currentTip(double progress) {
    if (progress < 0.28) return _statusTips[0];
    if (progress < 0.62) return _statusTips[1];
    if (progress < 0.90) return _statusTips[2];
    return _statusTips[3];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBlue,
        body: Stack(
          children: [
            // Decorative background soft circle (top-right)
            Positioned(
              right: -80,
              top: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kYellow.withValues(alpha: 0.25),
                ),
              ),
            ),

            // Decorative background soft circle (bottom-left)
            Positioned(
              left: -70,
              bottom: 120,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kLime.withValues(alpha: 0.18),
                ),
              ),
            ),

            // Floating Neo-Brutalist Sticker 1: Yellow Star ("★")
            AnimatedBuilder(
              animation: _bobbingController,
              builder: (context, child) {
                final angle = _bobbingController.value * 2 * math.pi;
                final offsetY = math.sin(angle) * 8.0;
                return Positioned(
                  top: size.height * 0.12 + offsetY,
                  left: 28,
                  child: Transform.rotate(
                    angle: -14 * math.pi / 180,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kYellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: kInk, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: kInk,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '★',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 26,
                          color: kInk,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Floating Neo-Brutalist Sticker 2: "PARTY READY" Pill
            AnimatedBuilder(
              animation: _bobbingController,
              builder: (context, child) {
                final angle = _bobbingController.value * 2 * math.pi;
                final offsetY = math.cos(angle) * 7.5;
                return Positioned(
                  top: size.height * 0.14 + offsetY,
                  right: 24,
                  child: Transform.rotate(
                    angle: 8 * math.pi / 180,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: kLime,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: kInk, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: kInk,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'PARTY READY',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 12,
                          color: kInk,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Floating Neo-Brutalist Sticker 3: Mini Star accent (mid-right)
            AnimatedBuilder(
              animation: _bobbingController,
              builder: (context, child) {
                final angle = _bobbingController.value * 2 * math.pi;
                final offsetY = math.sin(angle + 1.5) * 6.0;
                return Positioned(
                  top: size.height * 0.44 + offsetY,
                  right: 28,
                  child: Transform.rotate(
                    angle: 15 * math.pi / 180,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kCream,
                        shape: BoxShape.circle,
                        border: Border.all(color: kInk, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: kInk,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '★',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 18,
                          color: kInk,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Center Branding Section
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "FOREHEAD CHARADES" Black Pill Badge
                    Transform.rotate(
                      angle: 2 * math.pi / 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kInk,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: kCream, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          'FOREHEAD CHARADES',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 12,
                            color: kYellow,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tilted "Cipher!" Hero Title (fontSize: 68, 5px hard ink shadow)
                    Transform.rotate(
                      angle: -3.5 * math.pi / 180,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Cipher',
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 68,
                              height: 0.95,
                              color: kCream,
                              shadows: const [
                                Shadow(
                                  color: kInk,
                                  offset: Offset(5, 5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '!',
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 68,
                              height: 0.95,
                              color: kYellow,
                              shadows: const [
                                Shadow(
                                  color: kInk,
                                  offset: Offset(5, 5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // "ACT • GUESS • LAUGH" Yellow Sticker
                    Transform.rotate(
                      angle: 2.5 * math.pi / 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kYellow,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: kInk, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: kInk,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          'ACT • GUESS • LAUGH',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kInk,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Arcade Loading Bar Section
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: SafeArea(
                top: false,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _progressAnimation,
                    _stripeController,
                  ]),
                  builder: (context, child) {
                    final progress = _progressAnimation.value;
                    // Live percentage readout starting from 12% -> 100%
                    final displayPercent =
                        (12 + (progress * 88)).clamp(12, 100).round();
                    final tip = _currentTip(progress);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cycling Status Tip
                        SizedBox(
                          height: 24,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              tip,
                              key: ValueKey<String>(tip),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kCream,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Chunky Pill Progress Track (height: 32, kCream fill, 3px kInk border, 4px shadow)
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: kCream,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kInk, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: kInk,
                                offset: Offset(0, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                final fillWidth = totalWidth * progress;

                                return Stack(
                                  children: [
                                    // Animated kLime fill bar with candy diagonal stripes
                                    if (fillWidth > 0)
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: fillWidth,
                                        child: CustomPaint(
                                          painter: _CandyStripePainter(
                                            stripeShift: _stripeController.value,
                                            baseColor: kLime,
                                            stripeColor: const Color(0xFF9EDF00),
                                          ),
                                        ),
                                      ),

                                    // Live percentage readout (12% -> 100%) in Bowlby One
                                    Center(
                                      child: Text(
                                        '$displayPercent%',
                                        style: GoogleFonts.bowlbyOne(
                                          fontSize: 14,
                                          color: kInk,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering angled diagonal candy/arcade stripes
class _CandyStripePainter extends CustomPainter {
  final double stripeShift;
  final Color baseColor;
  final Color stripeColor;

  _CandyStripePainter({
    required this.stripeShift,
    required this.baseColor,
    required this.stripeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Paint solid base color
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 2. Paint angled diagonal stripes
    final stripePaint = Paint()
      ..color = stripeColor
      ..style = PaintingStyle.fill;

    const stripeWidth = 12.0;
    const stripeGap = 12.0;
    const step = stripeWidth + stripeGap;

    final shift = (stripeShift * step) % step;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (double x = -size.height - step + shift;
        x < size.width + step;
        x += step) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + stripeWidth + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CandyStripePainter oldDelegate) {
    return oldDelegate.stripeShift != stripeShift ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.stripeColor != stripeColor;
  }
}

