import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';

class AnonymousCreateScreen extends ConsumerStatefulWidget {
  const AnonymousCreateScreen({super.key});

  @override
  ConsumerState<AnonymousCreateScreen> createState() =>
      _AnonymousCreateScreenState();
}

class _AnonymousCreateScreenState
    extends ConsumerState<AnonymousCreateScreen> {
  final _groupNameController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final groupName = _groupNameController.text.trim();
    final name = _nameController.text.trim();
    if (groupName.isEmpty || name.isEmpty) return;

    setState(() => _loading = true);
    final groupId = await ref
        .read(authProvider.notifier)
        .createGroupAsAnonymous(groupName, name);
    if (mounted) {
      setState(() => _loading = false);
      if (groupId != null) {
        context.go('/groups/$groupId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    String? errorText;
    if (authState.errorKey == AuthErrorKey.anonymousCreateFailed) {
      errorText = l10n.anonymousCreateFailed;
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Mi Pueblo',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: l10n.groupName,
                  hintText: l10n.groupNameHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.yourName,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 24),
              if (errorText != null) ...[
                Text(
                  errorText,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.createGroup),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => context.go('/auth/join'),
                child: Text(l10n.haveInviteCode),
              ),
              TextButton(
                onPressed: () => context.go('/auth/login'),
                child: Text(l10n.alreadyHaveAccount),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
