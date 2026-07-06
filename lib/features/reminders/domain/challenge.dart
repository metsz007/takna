import 'dart:math';

/// A dismiss challenge: a problem to display and the integer that solves it.
typedef MathChallenge = ({String prompt, int answer});

/// Deterministic from [seed] (same seed → same problem, for tests and to
/// keep a re-render stable). Difficulty is fixed by construction: either a
/// two-digit addition or a small multiplication — bounded so a half-asleep
/// user can still solve it, not a brain-teaser.
MathChallenge generateMathChallenge(int seed) {
  final r = Random(seed);
  if (r.nextBool()) {
    final a = 10 + r.nextInt(90); // 10..99
    final b = 10 + r.nextInt(90);
    return (prompt: '$a + $b', answer: a + b);
  }
  final a = 2 + r.nextInt(11); // 2..12
  final b = 2 + r.nextInt(11);
  return (prompt: '$a × $b', answer: a * b);
}
// ponytail: one fixed difficulty band, math only. No per-reminder
// difficulty setting, no typed-phrase/shake variants — add a new branch here
// keyed off the `challenge` string only if users ask.
