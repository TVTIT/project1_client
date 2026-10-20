import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/session.dart';
import '../../core/router/routes.dart';
import 'auth_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final sessionState = ref.read(sessionProvider);
    if (_isLoading || sessionState.isRestoring) return;

    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _errorMessage = null;
    });

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ email và mật khẩu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .signIn(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Đã xảy ra sự cố xác thực. Vui lòng thử lại sau.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final sessionState = ref.watch(sessionProvider);
    final isBusy = _isLoading || sessionState.isRestoring;

    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Hệ thống Quản lý IoT & Digital Twin',
      fields: [
        if (sessionState.isRestoring)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KiteSpace.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: KiteSpace.sm),
                Text(
                  'Đang khôi phục phiên làm việc...',
                  style: t.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(KiteSpace.md),
            decoration: BoxDecoration(
              color: c.destructive.withValues(alpha: 0.08),
              borderRadius: KiteRadius.allSm,
              border: Border.all(color: c.destructive.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: c.destructive),
                const SizedBox(width: KiteSpace.sm),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: t.small.copyWith(
                      color: c.destructive,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KiteSpace.md),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Email',
                controller: _email,
                hint: 'user@company.com',
                keyboardType: TextInputType.emailAddress,
                onSubmitted: isBusy ? null : (_) => _handleSignIn(),
              ),
              const SizedBox(height: KiteSpace.md),
              AuthField(
                label: 'Mật khẩu',
                controller: _password,
                obscure: true,
                onSubmitted: isBusy ? null : (_) => _handleSignIn(),
              ),
              const SizedBox(height: KiteSpace.lg),
              KiteButton(
                expands: true,
                enabled: !isBusy,
                onPressed: _handleSignIn,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Đăng nhập'),
              ),
            ],
          ),
        ),
      ],
      footer: KiteButton.ghost(
        onPressed: () => context.go(R.license),
        child: Text(
          'Giấy phép (License)',
          style: t.small.copyWith(
            color: c.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
