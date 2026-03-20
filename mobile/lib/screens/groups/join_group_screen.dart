import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/providers/groups_provider.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final group = await ref
          .read(groupsProvider.notifier)
          .joinGroup(_codeController.text.trim());
      if (mounted) {
        context.go('/groups/${group.id}');
      }
    } catch (e) {
      setState(() => _error = 'Invalid or expired invite code');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the invite code shared by a group admin.'),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Invite Code',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _join,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join Group'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
