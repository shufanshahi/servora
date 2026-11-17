import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_text_field.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/features/auth/domain/auth_validators.dart';
import 'package:servora/features/profile/domain/profile_validators.dart';
import 'package:servora/features/profile/presentation/profile_controller.dart';

/// The Profile tab: your details (editable name and phone), change password, sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _changingPassword = false;

  AppUser? get _user {
    final session = ref.read(sessionProvider);
    return session is SessionAuthenticated ? session.user : null;
  }

  @override
  void initState() {
    super.initState();
    final user = _user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    // Show what we have at once, and quietly fetch the latest.
    unawaited(ref.read(profileControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  /// When fresher details arrive, update fields the user has not touched. Edits in
  /// progress are never overwritten.
  void _onUserChanged(AppUser? before, AppUser? after) {
    if (after == null) return;
    _email.text = after.email;
    if (_name.text == (before?.name ?? '')) _name.text = after.name;
    if (_phone.text == (before?.phone ?? '')) _phone.text = after.phone ?? '';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(profileControllerProvider.notifier)
        .save(name: _name.text, phone: _phone.text);
    if (saved && mounted) _message('Profile updated');
  }

  Future<void> _changePassword() async {
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    final changed = await ref
        .read(passwordControllerProvider.notifier)
        .change(currentPassword: _current.text, newPassword: _next.text);
    if (!changed || !mounted) return;
    _current.clear();
    _next.clear();
    setState(() => _changingPassword = false);
    _message('Password changed');
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to book services.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      _onUserChanged(
        previous is SessionAuthenticated ? previous.user : null,
        next is SessionAuthenticated ? next.user : null,
      );
    });
    final user = _user;
    final profile = ref.watch(profileControllerProvider);
    final profileController = ref.read(profileControllerProvider.notifier);
    final password = ref.watch(passwordControllerProvider);
    final passwordController = ref.read(passwordControllerProvider.notifier);
    final theme = Theme.of(context);

    return MaxContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Semantics(
            header: true,
            child: Text('Profile', style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.md),
          if (user != null) _Header(user: user),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile.failure != null) ...[
                  MessageBanner(
                    message: profile.failure!.userMessage,
                    onRetry: profile.failure!.isRetryable && !profile.isSaving
                        ? () => unawaited(_save())
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  label: 'Name',
                  controller: _name,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: AuthValidators.name,
                  errorText: profile.fieldErrors['name'],
                  onChanged: (_) => profileController.clearFieldError('name'),
                  enabled: !profile.isSaving,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  enabled: false,
                  hintText: 'Your email cannot be changed',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Phone (optional)',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-. ]')),
                  ],
                  validator: ProfileValidators.phone,
                  errorText: profile.fieldErrors['phone'],
                  onChanged: (_) => profileController.clearFieldError('phone'),
                  onSubmitted: (_) => unawaited(_save()),
                  enabled: !profile.isSaving,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save changes',
                  isLoading: profile.isSaving,
                  onPressed: () => unawaited(_save()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          if (!_changingPassword)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: 'Change password',
                icon: Icons.lock_outline,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () => setState(() => _changingPassword = true),
              ),
            )
          else
            Form(
              key: _passwordKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Change password', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  if (password.failure != null) ...[
                    MessageBanner(message: password.failure!.userMessage),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppTextField(
                    label: 'Current password',
                    controller: _current,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    validator: ProfileValidators.currentPassword,
                    errorText: password.fieldErrors['currentPassword'],
                    onChanged: (_) =>
                        passwordController.clearFieldError('currentPassword'),
                    enabled: !password.isSaving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'New password',
                    controller: _next,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    hintText: 'At least 8 characters, a letter and a number',
                    validator: AuthValidators.newPassword,
                    errorText: password.fieldErrors['newPassword'],
                    onChanged: (_) =>
                        passwordController.clearFieldError('newPassword'),
                    onSubmitted: (_) => unawaited(_changePassword()),
                    enabled: !password.isSaving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Update password',
                    isLoading: password.isSaving,
                    onPressed: () => unawaited(_changePassword()),
                  ),
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.text,
                    onPressed: password.isSaving
                        ? null
                        : () => setState(() {
                            _changingPassword = false;
                            _current.clear();
                            _next.clear();
                          }),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout,
            variant: AppButtonVariant.secondary,
            onPressed: () => unawaited(_signOut()),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().characters.first.toUpperCase();
    return Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              initial,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: theme.textTheme.titleMedium),
              Text(
                user.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
