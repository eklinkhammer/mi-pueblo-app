import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/groups_provider.dart';
import 'package:fence/providers/subscription_provider.dart';
import 'package:fence/widgets/upgrade_banner.dart';

class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      final group = await ref
          .read(groupsProvider.notifier)
          .createGroup(_nameController.text.trim());
      if (mounted) {
        context.go('/groups/${group.id}');
      }
    } on Exception catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedWithError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canCreate = ref.watch(canCreateGroupProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createGroup)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canCreate)
              UpgradeBanner(message: l10n.groupLimitReached),
            if (!canCreate) const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.groupName,
                border: const OutlineInputBorder(),
                hintText: l10n.groupNameHint,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.createGroup),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
