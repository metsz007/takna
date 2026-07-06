import 'package:flutter_test/flutter_test.dart';
import 'package:takna/features/reminders/domain/challenge.dart';

void main() {
  test('deterministic: same seed → same problem', () {
    final a = generateMathChallenge(42);
    final b = generateMathChallenge(42);
    expect(a.prompt, b.prompt);
    expect(a.answer, b.answer);
  });

  test('displayed problem and its answer never disagree', () {
    for (var seed = 0; seed < 100; seed++) {
      final c = generateMathChallenge(seed);
      final int expected;
      if (c.prompt.contains(' + ')) {
        final parts = c.prompt.split(' + ');
        expected = int.parse(parts[0]) + int.parse(parts[1]);
      } else {
        final parts = c.prompt.split(' × ');
        expected = int.parse(parts[0]) * int.parse(parts[1]);
      }
      expect(c.answer, expected, reason: 'seed $seed: "${c.prompt}"');
    }
  });

  test('difficulty stays bounded so a sleepy human can solve it', () {
    for (var seed = 0; seed < 100; seed++) {
      final c = generateMathChallenge(seed);
      if (c.prompt.contains(' + ')) {
        expect(c.answer, lessThanOrEqualTo(198)); // 99 + 99
      } else {
        expect(c.answer, lessThanOrEqualTo(144)); // 12 × 12
      }
    }
  });
}
