import 'package:flutter/material.dart';

const _palette = <Color>[
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
  return _palette[userId.hashCode.abs() % _palette.length];
}

String getInitials(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
}

class MemberMarker extends StatelessWidget {
  final String userId;
  final String displayName;
  final String timeAgo;

  const MemberMarker({
    super.key,
    required this.userId,
    required this.displayName,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = colorForUser(userId);
    final textColor =
        bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final firstName = displayName.split(RegExp(r'\s+')).first;

    return Tooltip(
      message: '$displayName\n$timeAgo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular avatar with initials
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              getInitials(displayName),
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Name label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              firstName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
