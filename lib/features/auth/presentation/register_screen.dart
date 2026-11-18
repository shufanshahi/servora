import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_text_field.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/features/auth/domain/auth_validators.dart';
import 'package:servora/features/auth/presentation/auth_form_controller.dart';
import 'package:servora/features/auth/presentation/auth_scaffold.dart';

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
    final failure = form.failure;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Book services and keep track of your appointments.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                prefixIcon: Icons.person_outline_rounded,
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
                prefixIcon: Icons.mail_outline_rounded,
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
                prefixIcon: Icons.lock_outline_rounded,
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                hintText: 'At least 8 characters, a letter and a number',
                validator: AuthValidators.newPassword,
                errorText: form.fieldErrors['password'],
                onChanged: (_) => controller.clearFieldError('password'),
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
    );
  }
}
