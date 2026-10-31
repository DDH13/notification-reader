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

  test('mediaCaption', () {
    expect(mediaCaption('\u{1F3A4} Voice message (0:12)'), '');
    expect(mediaCaption('\u{1F4F7} Photo'), '');
    expect(mediaCaption('Sticker'), '');
    expect(mediaCaption('\u{1F4F7} Sunset at the beach'), 'Sunset at the beach');
    expect(mediaCaption('hello'), 'hello');
  });
}
