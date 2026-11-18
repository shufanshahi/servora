import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_text_field.dart';
import 'package:servora/core/widgets/brand_mark.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/core/widgets/motion.dart';
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
  final _securityKey = GlobalKey();

  /// Shows the change-password form and scrolls it fully into view, so its
  /// buttons are not left under the navigation bar.
  void _openPasswordForm() {
    setState(() => _changingPassword = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _securityKey.currentContext;
      if (target == null || !mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: reduceMotion(context) ? Duration.zero : AppMotion.medium,
          curve: AppMotion.emphasized,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

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

    return SafeArea(
      bottom: false,
      child: MaxContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          children: [
            FadeSlideIn(
              offset: const Offset(0, -12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Your account'),
                  const SizedBox(height: 2),
                  Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      'Profile',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (user != null)
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _Header(user: user),
              ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle(
              icon: Icons.badge_outlined,
              title: 'Personal details',
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md + 4),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (profile.failure != null) ...[
                        MessageBanner(
                          message: profile.failure!.userMessage,
                          onRetry:
                              profile.failure!.isRetryable && !profile.isSaving
                              ? () => unawaited(_save())
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppTextField(
                        label: 'Name',
                        prefixIcon: Icons.person_outline_rounded,
                        controller: _name,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: AuthValidators.name,
                        errorText: profile.fieldErrors['name'],
                        onChanged: (_) =>
                            profileController.clearFieldError('name'),
                        enabled: !profile.isSaving,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Email',
                        prefixIcon: Icons.mail_outline_rounded,
                        controller: _email,
                        enabled: false,
                        hintText: 'Your email cannot be changed',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Phone (optional)',
                        prefixIcon: Icons.phone_outlined,
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+()\-. ]'),
                          ),
                        ],
                        validator: ProfileValidators.phone,
                        errorText: profile.fieldErrors['phone'],
                        onChanged: (_) =>
                            profileController.clearFieldError('phone'),
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
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle(icon: Icons.shield_outlined, title: 'Security'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              key: _securityKey,
              child: KeyedSubtree(
                child: !_changingPassword
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppButton(
                          label: 'Change password',
                          icon: Icons.lock_outline,
                          variant: AppButtonVariant.text,
                          expand: false,
                          onPressed: () => _openPasswordForm(),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs + 4),
                        child: Form(
                          key: _passwordKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Change password',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (password.failure != null) ...[
                                MessageBanner(
                                  message: password.failure!.userMessage,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              AppTextField(
                                label: 'Current password',
                                prefixIcon: Icons.lock_outline_rounded,
                                controller: _current,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.password],
                                validator: ProfileValidators.currentPassword,
                                errorText:
                                    password.fieldErrors['currentPassword'],
                                onChanged: (_) => passwordController
                                    .clearFieldError('currentPassword'),
                                enabled: !password.isSaving,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                label: 'New password',
                                prefixIcon: Icons.key_rounded,
                                controller: _next,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                hintText: 'At least 8 characters, a letter and a number',
                                validator: AuthValidators.newPassword,
                                errorText: password.fieldErrors['newPassword'],
                                onChanged: (_) => passwordController
                                    .clearFieldError('newPassword'),
                                onSubmitted: (_) =>
                                    unawaited(_changePassword()),
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
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(_signOut()),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// A small heading with an icon, above a card of settings.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.gold),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ],
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
    // A membership card: the brand gradient, the user's monogram and details.
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.lifted,
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const RingsPainter(origin: Alignment(1.1, -1.2)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg - 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDeep,
                        ),
                        child: Text(
                          initial,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.goldLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const ExcludeSemantics(child: BrandTile(size: 22)),
                  Text(
                    'Member since ${DateFormat('MMMM y', 'en_US').format(user.createdAt.toLocal())}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.goldLight,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
