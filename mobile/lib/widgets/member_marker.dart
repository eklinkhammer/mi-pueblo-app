import 'package:flutter/material.dart';
import 'package:fence/utils/avatar_url.dart';
import 'package:fence/utils/user_colors.dart';

class MemberMarker extends StatelessWidget {
  final String userId;
  final String displayName;
  final String timeAgo;
  final String? avatarUrl;

  const MemberMarker({
    super.key,
    required this.userId,
    required this.displayName,
    required this.timeAgo,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = colorForUser(userId);
    final textColor =
        bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;
    final resolvedUrl = fullAvatarUrl(avatarUrl);

    return Tooltip(
      message: '$displayName\n$timeAgo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular avatar with image or initials
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: resolvedUrl == null ? bgColor : null,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              image: resolvedUrl != null
                  ? DecorationImage(
                      image: NetworkImage(resolvedUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: resolvedUrl == null
                ? Text(
                    getInitials(displayName),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 2),
          // Name label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              firstName,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
