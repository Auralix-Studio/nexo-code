import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';

/// Pantalla "Cambiar contraseña" — consume `Login/ChangePassword`.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();
  bool _loading = false;
  bool _showActual = false;
  bool _showNueva = false;
  String? _error;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.store.changePassword(_actualCtrl.text, _nuevaCtrl.text);
      if (!mounted) return;
      ClipboardHelper.showSuccess(context, l.changePasswordSuccess);
      navigator.pop();
    } on UnauthorizedException catch (e) {
      _error = e.message;
    } on BadRequestException catch (e) {
      _error = e.message;
    } on NetworkException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.titleChangePassword)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.changePasswordHeader,
                      style: TextStyle(
                        fontSize: AppFont.h2,
                        fontWeight: FontWeight.w900,
                        color: NexoTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      l.changePasswordSubheader,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        color: NexoTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const Gap(AppSpacing.xxxl),
                    TextFormField(
                      controller: _actualCtrl,
                      obscureText: !_showActual,
                      decoration: InputDecoration(
                        labelText: l.changePasswordCurrentLabel,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: NexoTheme.textSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showActual
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: NexoTheme.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _showActual = !_showActual),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? l.validationRequired
                          : null,
                    ),
                    const Gap(AppSpacing.md),
                    TextFormField(
                      controller: _nuevaCtrl,
                      obscureText: !_showNueva,
                      decoration: InputDecoration(
                        labelText: l.changePasswordNewLabel,
                        prefixIcon: Icon(
                          Icons.lock_reset_rounded,
                          color: NexoTheme.textSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showNueva
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: NexoTheme.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _showNueva = !_showNueva),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l.validationRequired;
                        }
                        if (v.length < 6) {
                          return l.changePasswordMinChars(6);
                        }
                        if (v == _actualCtrl.text) {
                          return l.changePasswordMustBeDifferent;
                        }
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.md),
                    TextFormField(
                      controller: _repetirCtrl,
                      obscureText: !_showNueva,
                      decoration: InputDecoration(
                        labelText: l.changePasswordRepeatLabel,
                        prefixIcon: Icon(
                          Icons.check_circle_outline,
                          color: NexoTheme.textSecondary,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l.validationRequired;
                        }
                        if (v != _nuevaCtrl.text) {
                          return l.changePasswordNoMatch;
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const Gap(AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: NexoTheme.danger.withValues(alpha: 0.08),
                          borderRadius: AppRadii.rMd,
                          border: Border.all(
                            color: NexoTheme.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: NexoTheme.danger,
                            ),
                            const Gap.h(AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: NexoTheme.danger,
                                  fontSize: AppFont.body,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Gap(AppSpacing.xl),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l.changePasswordUpdateButton,
                                style: const TextStyle(
                                  fontSize: AppFont.title,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
