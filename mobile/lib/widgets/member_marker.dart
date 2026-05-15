import 'package:flutter/material.dart';
import 'package:fence/utils/user_colors.dart';

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
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;

    return Tooltip(
      message: '$displayName\n$timeAgo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular avatar with initials
          Container(
            width: 30,
            height: 30,
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
                fontSize: 12,
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
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
