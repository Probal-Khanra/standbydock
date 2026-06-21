import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/standby_screen.dart' show ClockStyle;

/// Clock panel containing HH:MM:SS time displays with customizable clock styles.
class ClockPanel extends StatefulWidget {
  final Color accentColor;
  final ClockStyle clockStyle;

  const ClockPanel({
    super.key,
    required this.accentColor,
    required this.clockStyle,
  });

  @override
  State<ClockPanel> createState() => _ClockPanelState();
}

class _ClockPanelState extends State<ClockPanel> {
  late final ValueNotifier<DateTime> _timeNotifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeNotifier = ValueNotifier(DateTime.now());
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ClockPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clockStyle != oldWidget.clockStyle) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.clockStyle == ClockStyle.analog) {
      // High frequency (60fps / 16ms updates) for smooth analog sweep
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    } else {
      // Low frequency (1Hz / 1s updates) for energy-saving digital time
      _tick();
      final now = DateTime.now();
      final msUntilNextSecond = 1000 - now.millisecond;
      // Start aligned to second boundary
      Future.delayed(Duration(milliseconds: msUntilNextSecond), () {
        if (!mounted || widget.clockStyle == ClockStyle.analog) return;
        _tick();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      });
    }
  }

  void _tick() {
    if (!mounted) return;
    _timeNotifier.value = DateTime.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---- Animated switcher for smooth clock style crossfades ----
          Expanded(
            child: Center(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: _timeNotifier,
                builder: (context, dateTime, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildClockFace(dateTime),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ---- Date display ----
          ValueListenableBuilder<DateTime>(
            valueListenable: _timeNotifier,
            builder: (context, dateTime, _) {
              return Text(
                _formatDate(dateTime),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 2.0,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockFace(DateTime dateTime) {
    final timeStr = _formatTime(dateTime);

    switch (widget.clockStyle) {
      case ClockStyle.minimalist:
        return FittedBox(
          key: const ValueKey('minimalist_clock'),
          fit: BoxFit.scaleDown,
          child: Text(
            timeStr,
            style: GoogleFonts.outfit(
              fontSize: 110,
              fontWeight: FontWeight.w200,
              color: widget.accentColor.withValues(alpha: 0.85),
              letterSpacing: 6,
              height: 1.0,
            ),
          ),
        );

      case ClockStyle.bold:
        return FittedBox(
          key: const ValueKey('bold_clock'),
          fit: BoxFit.scaleDown,
          child: Text(
            timeStr,
            style: GoogleFonts.orbitron(
              fontSize: 85,
              fontWeight: FontWeight.w800,
              color: widget.accentColor,
              shadows: [
                Shadow(
                  color: widget.accentColor.withValues(alpha: 0.35),
                  blurRadius: 15,
                ),
              ],
              letterSpacing: 4,
              height: 1.0,
            ),
          ),
        );

      case ClockStyle.flip:
        return FittedBox(
          key: const ValueKey('flip_clock'),
          fit: BoxFit.scaleDown,
          child: _buildFlipClock(timeStr),
        );

      case ClockStyle.analog:
        return _buildAnalogClock(dateTime);
    }
  }

  Widget _buildFlipClock(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 3) return const SizedBox();
    final hh = parts[0];
    final mm = parts[1];
    final ss = parts[2];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFlipCard(hh, 'Hour'),
        _buildFlipDivider(),
        _buildFlipCard(mm, 'Min'),
        _buildFlipDivider(),
        _buildFlipCard(ss, 'Sec'),
      ],
    );
  }

  Widget _buildFlipDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: widget.accentColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildFlipCard(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center Split Card Line
              Positioned(
                left: 0,
                right: 0,
                height: 1,
                child: Container(
                  color: Colors.black,
                ),
              ),
              // Time digits
              Center(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.25),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      value,
                      key: ValueKey<String>(value),
                      style: GoogleFonts.outfit(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalogClock(DateTime dateTime) {
    return AspectRatio(
      key: const ValueKey('analog_clock'),
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.05),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _AnalogClockPainter(dateTime, widget.accentColor),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime dateTime;
  final Color accentColor;

  _AnalogClockPainter(this.dateTime, this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw clock face outer ring
    canvas.drawCircle(center, radius, paint);

    // Draw major & minor tick marks
    final markPaint = Paint()
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * pi / 180;
      final isMajor = i % 3 == 0;
      final startRadius = radius - (isMajor ? 12 : 6);
      final endRadius = radius - 2;

      final start = Offset(
        center.dx + startRadius * sin(angle),
        center.dy - startRadius * cos(angle),
      );
      final end = Offset(
        center.dx + endRadius * sin(angle),
        center.dy - endRadius * cos(angle),
      );
      markPaint.color = Colors.white.withValues(alpha: isMajor ? 0.35 : 0.12);
      markPaint.strokeWidth = isMajor ? 2.5 : 1.5;
      canvas.drawLine(start, end, markPaint);
    }

    // Hour Hand
    final hourAngle = ((dateTime.hour % 12) * 30 + dateTime.minute * 0.5) * pi / 180;
    final hourHandLength = radius * 0.52;
    final hourPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + hourHandLength * sin(hourAngle), center.dy - hourHandLength * cos(hourAngle)),
      hourPaint,
    );

    // Minute Hand
    final minuteAngle = (dateTime.minute * 6 + dateTime.second * 0.1) * pi / 180;
    final minuteHandLength = radius * 0.72;
    final minutePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + minuteHandLength * sin(minuteAngle), center.dy - minuteHandLength * cos(minuteAngle)),
      minutePaint,
    );

    // Second Hand (Sweeps in accent color, smooth 60fps motion)
    final secondAngle = (dateTime.second * 6 + dateTime.millisecond * 0.006) * pi / 180;
    final secondHandLength = radius * 0.82;
    final secondPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + secondHandLength * sin(secondAngle), center.dy - secondHandLength * cos(secondAngle)),
      secondPaint,
    );

    // Pivot Circle center dot
    final pivotPaint = Paint()..color = accentColor;
    canvas.drawCircle(center, 4, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.dateTime != dateTime || oldDelegate.accentColor != accentColor;
  }
}
