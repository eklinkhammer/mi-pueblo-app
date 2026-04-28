import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';

class AnonymousJoinScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const AnonymousJoinScreen({super.key, this.initialCode});

  @override
  ConsumerState<AnonymousJoinScreen> createState() =>
      _AnonymousJoinScreenState();
}

class _AnonymousJoinScreenState extends ConsumerState<AnonymousJoinScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) return;

    setState(() => _loading = true);
    await ref.read(authProvider.notifier).joinAsAnonymous(code, name);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    String? errorText;
    if (authState.errorKey == AuthErrorKey.invalidInviteCode) {
      errorText = l10n.errorInvalidInviteCode;
    } else if (authState.errorKey == AuthErrorKey.inviteCodeExpired) {
      errorText = l10n.errorInviteCodeExpired;
    } else if (authState.errorKey == AuthErrorKey.anonymousJoinFailed) {
      errorText = l10n.anonymousJoinFailed;
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go('/auth/create'),
                      ),
                    ),
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
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: l10n.groupCodePrompt,
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.yourName,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _join(),
                    ),
                    const SizedBox(height: 24),
                    if (errorText != null) ...[
                      Text(
                        errorText,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _loading ? null : _join,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.joinButton),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => context.go('/auth/create'),
                      child: Text(l10n.createNewGroup),
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
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
