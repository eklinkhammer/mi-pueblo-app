import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/history_provider.dart';

/// Reusable list of geofence history events for a given user.
///
/// Used both in the full-screen history screen and the map history drawer.
/// An optional [scrollController] can be provided when this is embedded inside
/// a [DraggableScrollableSheet].
class HistoryEventList extends ConsumerWidget {
  final String userId;
  final ScrollController? scrollController;

  const HistoryEventList({
    super.key,
    required this.userId,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final eventsAsync = ref.watch(historyProvider(userId));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return ListView(
            controller: scrollController,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: Center(child: Text(l10n.noHistoryYet)),
              ),
            ],
          );
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isEntered = event.event == 'entered';
            return ListTile(
              leading: Icon(
                isEntered ? Icons.login : Icons.logout,
                color: isEntered ? Colors.green : Colors.red,
              ),
              title: Text(event.geofenceName),
              subtitle: Text(_timeAgo(event.insertedAt, l10n)),
              trailing: Text(
                isEntered ? l10n.entered : l10n.exited,
                style: TextStyle(
                  color: isEntered ? Colors.green : Colors.red,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(l10n.errorWithMessage(e.toString()))),
    );
  }

  String _timeAgo(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return l10n.timeAgoJustNow;
    if (diff.inHours < 1) return l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.timeAgoHours(diff.inHours);
    return l10n.timeAgoDays(diff.inDays);
  }
}
