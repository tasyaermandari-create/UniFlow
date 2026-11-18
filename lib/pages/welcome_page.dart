import 'dart:async';

import 'package:flutter/material.dart';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  Timer? _timer;

  static const Color primaryBlue = Color(0xFF2166C2);
  static const Color darkBlue = Color(0xFF173B70);
  static const Color lightBlue = Color(0xFFDCEBFF);

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEAF3FF),
                    Color(0xFFFFFFFF),
                    Color(0xFFE6F0FF),
                  ],
                ),
              ),
            ),

            // Dekorasi lingkaran bagian atas
            Positioned(top: -75, right: -55, child: _decorationCircle(190)),

            Positioned(top: 120, left: -75, child: _decorationCircle(140)),

            // Gelombang bagian bawah
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 230,
              child: CustomPaint(painter: _WavePainter()),
            ),

            // Konten utama
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo topi wisuda
                    Container(
                      width: 155,
                      height: 145,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withValues(alpha: 0.10),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 100,
                        color: primaryBlue,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Nama aplikasi
                    const Text(
                      'UniFlow',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: darkBlue,
                        letterSpacing: -1.5,
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Tagline
                    const Text(
                      'Your Day, Your Flow.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Indikator loading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _loadingDot(0.35),
                        const SizedBox(width: 7),
                        _loadingDot(0.65),
                        const SizedBox(width: 7),
                        _loadingDot(1),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tulisan kecil bagian bawah
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Text(
                'SMART STUDENT LIFE PLANNER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: darkBlue.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorationCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: lightBlue.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _loadingDot(double opacity) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

// Custom gelombang background
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFD6E7FF)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.38)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.05,
        size.width * 0.60,
        size.height * 0.40,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.65,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = const Color(0xFFBBD6FF).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.32,
        size.width * 0.65,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.88,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
