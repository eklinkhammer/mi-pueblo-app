import 'package:flutter/material.dart';

const palette = <Color>[
  Color(0xFFE53935), // red
  Color(0xFF8E24AA), // purple
  Color(0xFF3949AB), // indigo
  Color(0xFF039BE5), // light blue
  Color(0xFF00897B), // teal
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFFFB8C00), // orange
  Color(0xFF6D4C41), // brown
  Color(0xFF546E7A), // blue grey
  Color(0xFFD81B60), // pink
  Color(0xFF00ACC1), // cyan
];

Color colorForUser(String userId) {
  return palette[userId.hashCode.abs() % palette.length];
}

String getInitials(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return parts.first[0].toUpperCase();
}
