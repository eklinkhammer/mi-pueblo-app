import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/providers/groups_provider.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., The Smiths',
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
                  : const Text('Create Group'),
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
