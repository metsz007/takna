import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A reusable animated (or static) wave background for Takna.
///
/// Draws three stacked sine-wave layers over a vertical gradient base,
/// in the Takna palette (teal-navy + amber). Place it behind a Scaffold
/// body via a Stack, or pass your screen content as [child].
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: WaveBackground(
///     child: YourHomeContent(),
///   ),
/// )
/// ```
///
/// For inner screens where constant motion isn't wanted, disable animation:
/// ```dart
/// WaveBackground(animate: false, child: YourDetailContent())
/// ```
class WaveBackground extends StatefulWidget {
  const WaveBackground({
    super.key,
    this.child,
    this.animate = true,
    this.dark = false,
    this.duration = const Duration(seconds: 24),
  });

  /// Content rendered on top of the waves.
  final Widget? child;

  /// When false, the waves are drawn once (no animation). Use on inner
  /// screens to keep the visual identity without the battery cost.
  final bool animate;

  /// Dark variant of the palette. Wire this to Theme.of(context) if you
  /// prefer: `dark: Theme.of(context).brightness == Brightness.dark`.
  final bool dark;

  /// Duration of one full drift loop.
  final Duration duration;

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  // One shared clock for every instance: the phase is derived from elapsed
  // app time, so waves are in the same position on every screen and never
  // reset on navigation.
  static final Stopwatch _clock = Stopwatch()..start();

  double get _phase =>
      (_clock.elapsedMilliseconds / widget.duration.inMilliseconds) *
      2 *
      math.pi;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // The controller is only a repaint ticker; the actual phase
            // comes from the shared clock (continuous across screens).
            return CustomPaint(
              painter: _WavePainter(
                t: _phase,
                dark: widget.dark,
              ),
              isComplex: true,
              willChange: widget.animate,
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _WaveLayer {
  const _WaveLayer({
    required this.amplitude,
    required this.wavelength,
    required this.speed,
    required this.yBase,
    required this.color,
  });

  /// Peak height of the wave, in logical pixels.
  final double amplitude;

  /// Higher = more, tighter waves across the width.
  final double wavelength;

  /// Relative drift speed multiplier.
  final double speed;

  /// Vertical anchor as a fraction of height (0.0 top -> 1.0 bottom).
  final double yBase;

  final Color color;
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.t, required this.dark});

  final double t;
  final bool dark;

  // Palette — matches the Takna brand + the approved preview.
  // Light base stays cream so the light theme's dark-teal ink stays readable;
  // waves are soft teal/amber washes over it.
  static const _lightBaseTop = Color(0xFFF2EBDA);
  static const _lightBaseBottom = Color(0xFFEADFC8);
  static const _darkBaseTop = Color(0xFF10313A);
  static const _darkBaseBottom = Color(0xFF081C22);

  List<_WaveLayer> _layers() {
    // Speeds must be whole numbers: t sweeps 0→2π per loop, so integer
    // multiples land each wave exactly where it started (seamless wrap).
    if (dark) {
      return const [
        _WaveLayer(amplitude: 26, wavelength: 0.011, speed: 2, yBase: 0.42, color: Color(0x3831C695)),
        _WaveLayer(amplitude: 32, wavelength: 0.009, speed: 1, yBase: 0.60, color: Color(0x2EE0A43B)),
        _WaveLayer(amplitude: 22, wavelength: 0.014, speed: 1, yBase: 0.78, color: Color(0x1AE0A43B)),
      ];
    }
    return const [
      _WaveLayer(amplitude: 26, wavelength: 0.011, speed: 2, yBase: 0.42, color: Color(0x21173B44)),
      _WaveLayer(amplitude: 32, wavelength: 0.009, speed: 1, yBase: 0.60, color: Color(0x2EE0A43B)),
      _WaveLayer(amplitude: 22, wavelength: 0.014, speed: 1, yBase: 0.78, color: Color(0x3DE0A43B)),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base vertical gradient.
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [_darkBaseTop, _darkBaseBottom]
            : const [_lightBaseTop, _lightBaseBottom],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // Wave layers.
    for (var i = 0; i < _layers().length; i++) {
      final layer = _layers()[i];
      final path = Path()..moveTo(0, size.height);

      for (double x = 0; x <= size.width; x += 4) {
        final y = size.height * layer.yBase +
            math.sin(x * layer.wavelength + t * layer.speed + i) * layer.amplitude +
            // secondary swell: speed * 2 stays a whole number, so the loop
            // wrap remains seamless
            math.sin(x * layer.wavelength * 0.5 + t * layer.speed * 2) *
                layer.amplitude *
                0.4;
        path.lineTo(x, y);
      }

      path
        ..lineTo(size.width, size.height)
        ..close();

      canvas.drawPath(path, Paint()..color = layer.color);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.dark != dark;
}
