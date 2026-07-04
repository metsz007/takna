import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens lifted 1:1 from design/Takna.dc.html.
class Tk extends ThemeExtension<Tk> {
  const Tk({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.onAccent,
    required this.heroBg,
    required this.heroInk,
    required this.heroSub,
    required this.navBg,
    required this.navLine,
    required this.ic1,
    required this.ic2,
    required this.toggleOff,
    required this.toggleKnob,
    required this.field,
    required this.ok,
    required this.okSoft,
  });

  final Color bg, surface, surface2, ink, ink2, ink3, line, line2;
  final Color accent, accentSoft, accentInk, onAccent;
  final Color heroInk, heroSub, navBg, navLine, ic1, ic2;
  final Color toggleOff, toggleKnob, field, ok, okSoft;
  final Gradient heroBg;

  static const light = Tk(
    bg: Color(0xFFF2EBDA),
    surface: Color(0xFFFCFAF3),
    surface2: Color(0xFFEFE7D6),
    ink: Color(0xFF173B44),
    ink2: Color(0x9E173B44),
    ink3: Color(0x6B173B44),
    line: Color(0x14173B44),
    line2: Color(0x24173B44),
    accent: Color(0xFFE0A43B),
    accentSoft: Color(0xFFF6E7C6),
    accentInk: Color(0xFF8A6A1F),
    onAccent: Color(0xFF173B44),
    heroBg: LinearGradient(colors: [Color(0xFF173B44), Color(0xFF173B44)]),
    heroInk: Color(0xFFF2EBDA),
    heroSub: Color(0xC7F2EBDA),
    navBg: Color(0xFFFCFAF3),
    navLine: Color(0x12173B44),
    ic1: Color(0xFF173B44),
    ic2: Color(0xFFE0A43B),
    toggleOff: Color(0xFFD8D2C4),
    toggleKnob: Colors.white,
    field: Color(0xFFF3ECDD),
    ok: Color(0xFF3E8E6E),
    okSoft: Color(0x243E8E6E),
  );

  static const dark = Tk(
    bg: Color(0xFF0E272E),
    surface: Color(0xFF17363D),
    surface2: Color(0xFF1C454F),
    ink: Color(0xFFF2EBDA),
    ink2: Color(0x99F2EBDA),
    ink3: Color(0x66F2EBDA),
    line: Color(0x12F2EBDA),
    line2: Color(0x1FF2EBDA),
    accent: Color(0xFFE0A43B),
    accentSoft: Color(0x29E0A43B),
    accentInk: Color(0xFFE0A43B),
    onAccent: Color(0xFF173B44),
    heroBg: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1C454F), Color(0xFF173B44)]),
    heroInk: Color(0xFFF2EBDA),
    heroSub: Color(0xB3F2EBDA),
    navBg: Color(0xFF0B1E24),
    navLine: Color(0x12F2EBDA),
    ic1: Color(0xFFE0A43B),
    ic2: Color(0xFFF2EBDA),
    toggleOff: Color(0x29F2EBDA),
    toggleKnob: Color(0xFFF2EBDA),
    field: Color(0xFF123138),
    ok: Color(0xFF57C79A),
    okSoft: Color(0x2957C79A),
  );

  @override
  Tk copyWith() => this;
  @override
  Tk lerp(Tk? other, double t) => t < .5 ? this : (other ?? this);
}

extension TkContext on BuildContext {
  Tk get tk => Theme.of(this).extension<Tk>()!;
}

TextStyle body(double size, FontWeight w, Color c, {double? height, double? spacing}) =>
    GoogleFonts.figtree(
        fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: spacing);

TextStyle display(double size, FontWeight w, Color c, {double? spacing}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: c, letterSpacing: spacing);

ThemeData themeFor(Brightness b) {
  final t = b == Brightness.light ? Tk.light : Tk.dark;
  return ThemeData(
    brightness: b,
    scaffoldBackgroundColor: t.bg,
    colorScheme: ColorScheme.fromSeed(
        seedColor: t.ink, brightness: b, primary: t.accent, surface: t.bg),
    textTheme: GoogleFonts.figtreeTextTheme(
        b == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme),
    extensions: [t],
  );
}
