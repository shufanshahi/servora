import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_text_field.dart';
import 'package:servora/core/widgets/centered_scroll.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/features/auth/domain/auth_validators.dart';
import 'package:servora/features/auth/presentation/auth_form_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref
        .read(registerControllerProvider.notifier)
        .register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(registerControllerProvider);
    final controller = ref.read(registerControllerProvider.notifier);
    final theme = Theme.of(context);
    final failure = form.failure;

    return Scaffold(
      body: SafeArea(
        child: MaxContentWidth(
          child: CenteredScroll(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create your account',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Book services and keep track of your appointments.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (failure != null) ...[
                        MessageBanner(
                          message: failure.userMessage,
                          onRetry: failure.isRetryable && !form.isSubmitting
                              ? _submit
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
                        errorText: form.fieldErrors['name'],
                        onChanged: (_) => controller.clearFieldError('name'),
                        enabled: !form.isSubmitting,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        validator: AuthValidators.email,
                        errorText: form.fieldErrors['email'],
                        onChanged: (_) => controller.clearFieldError('email'),
                        enabled: !form.isSubmitting,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Password',
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        hintText:
                            'At least 8 characters, a letter and a number',
                        validator: AuthValidators.newPassword,
                        errorText: form.fieldErrors['password'],
                        onChanged: (_) =>
                            controller.clearFieldError('password'),
                        onSubmitted: (_) => _submit(),
                        enabled: !form.isSubmitting,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Create account',
                        isLoading: form.isSubmitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'I already have an account',
                        variant: AppButtonVariant.text,
                        onPressed: form.isSubmitting
                            ? null
                            : () => context.go(AppRoutes.login),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
