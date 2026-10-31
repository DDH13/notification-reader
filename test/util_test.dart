import 'package:flutter_test/flutter_test.dart';
import 'package:recover/util.dart';

void main() {
  final now = DateTime(2024, 5, 10, 15);

  test('formatListTime', () {
    expect(formatListTime(DateTime(2024, 5, 9, 9), now), 'Yesterday');
    expect(formatListTime(DateTime(2023, 1, 2), now), '02/01/2023');
  });

  test('initials', () {
    expect(initials('Ada Lovelace'), 'AL');
    expect(initials('bob'), 'B');
    expect(initials(''), '?');
  });
}
