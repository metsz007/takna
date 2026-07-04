import 'package:flutter/material.dart';

import 'theme.dart';

/// Segmented control (the design's pill-in-track selector).
class TkSegmented<T> extends StatelessWidget {
  const TkSegmented(
      {super.key, required this.options, required this.value, required this.onChanged, this.labelOf});
  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: o == value ? t.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(labelOf?.call(o) ?? '$o',
                      style: body(11.5, FontWeight.w600, o == value ? t.onAccent : t.ink2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The design's custom 42x25 toggle.
class TkToggle extends StatelessWidget {
  const TkToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 25,
        decoration: BoxDecoration(
            color: value ? t.accent : t.toggleOff, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(2.5),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: t.toggleKnob,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// Surface card with the design's border + radius.
class TkCard extends StatelessWidget {
  const TkCard({super.key, required this.child, this.padding, this.margin, this.onTap});
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Amber-soft rounded icon box used on list rows and permission cards.
class TkIconBox extends StatelessWidget {
  const TkIconBox({super.key, required this.icon, this.size = 38});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(size * .32)),
      child: Icon(icon, size: size * .52, color: t.ic1),
    );
  }
}

/// Small amber badge ("Daily", "in 2h", ...).
class TkBadge extends StatelessWidget {
  const TkBadge(this.label, {super.key, this.filled = false});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? t.accent : t.accentSoft,
        borderRadius: BorderRadius.circular(filled ? 20 : 6),
      ),
      child: Text(label,
          style: body(filled ? 10 : 9.5, FontWeight.w700,
              filled ? const Color(0xFF173B44) : t.accentInk)),
    );
  }
}

/// "DEFAULTS" / "RELIABILITY" section label.
class TkSectionLabel extends StatelessWidget {
  const TkSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        child: Text(text.toUpperCase(),
            style: body(11, FontWeight.w700, context.tk.ink3, spacing: 1)),
      );
}

/// Square icon button (back / close / delete in headers).
class TkIconButton extends StatelessWidget {
  const TkIconButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: t.ink),
      ),
    );
  }
}

/// Teal hero container with the amber radial glow.
class TkHero extends StatelessWidget {
  const TkHero({super.key, required this.child, this.radius = 26, this.padding});
  final Widget child;
  final double radius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        gradient: t.heroBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x2EE0A43B)),
        boxShadow: const [
          BoxShadow(color: Color(0x73173B44), blurRadius: 34, offset: Offset(0, 16), spreadRadius: -12)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(children: [
          Positioned(
            right: -34,
            top: -42,
            child: Container(
              width: 145,
              height: 145,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0x4DE0A43B), Color(0x00E0A43B)], stops: [0, .7]),
              ),
            ),
          ),
          Padding(padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 17), child: child),
        ]),
      ),
    );
  }
}
