import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const waDark = Color(0xFF075E54);
const waGreen = Color(0xFF25D366);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Chat-list style: time today, "Yesterday", weekday this week, else date.
String formatListTime(DateTime t, [DateTime? now]) {
  now ??= DateTime.now();
  final diff = _day(now).difference(_day(t)).inDays;
  if (diff <= 0) return DateFormat.jm().format(t);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.EEEE().format(t);
  return DateFormat('dd/MM/yyyy').format(t);
}

/// Date chip label in a conversation.
String formatDayChip(DateTime t, [DateTime? now]) {
  now ??= DateTime.now();
  final diff = _day(now).difference(_day(t)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat.yMMMMd().format(t);
}

bool sameDay(DateTime a, DateTime b) => _day(a) == _day(b);

String initials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map((s) => String.fromCharCode(s.runes.first))
      .toList();
  if (parts.isEmpty) return '?';
  return (parts.length == 1 ? parts.first : parts.first + parts[1]).toUpperCase();
}

const _senderColors = [
  Color(0xFFD32F2F), Color(0xFF7B1FA2), Color(0xFF303F9F), Color(0xFF0277BD),
  Color(0xFF00796B), Color(0xFF558B2F), Color(0xFFEF6C00), Color(0xFF6D4C41),
  Color(0xFFC2185B), Color(0xFF00838F),
];

Color senderColor(String name) {
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _senderColors[h % _senderColors.length];
}

final _mediaEmoji =
    RegExp(r'^(\u{1F3A4}|\u{1F4F7}|\u{1F3A5}|\u{1F3B5}|\u{1F4C4})\uFE0F?\s*', unicode: true);
final _mediaPlaceholder = RegExp(
    r'^(voice message|photo|video|audio|document|sticker|gif)(\s*\(\d+(:\d+)+\))?$',
    caseSensitive: false);

/// The message text minus WhatsApp's media emoji/placeholder, i.e. the caption.
String mediaCaption(String text) {
  final t = text.trim().replaceFirst(_mediaEmoji, '');
  return _mediaPlaceholder.hasMatch(t) ? '' : t;
}
