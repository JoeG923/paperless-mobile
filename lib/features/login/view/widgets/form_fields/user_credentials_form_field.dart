import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';

import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/features/login/model/login_form_credentials.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/obscured_input_text_form_field.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/server_address_form_field.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class UserCredentialsFormField extends StatefulWidget {
  static const fkCredentials = 'credentials';

  final VoidCallback? onFieldsSubmitted;
  final String? initialUsername;
  final String? initialPassword;
  final GlobalKey<FormBuilderState> formKey;
  const UserCredentialsFormField({
    super.key,
    this.onFieldsSubmitted,
    this.initialUsername,
    this.initialPassword,
    required this.formKey,
  });

  @override
  State<UserCredentialsFormField> createState() =>
      _UserCredentialsFormFieldState();
}

class _UserCredentialsFormFieldState extends State<UserCredentialsFormField>
    with AutomaticKeepAliveClientMixin {
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _mfaFocusNode = FocusNode();
  bool _useApiToken = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FormBuilderField<LoginFormCredentials?>(
      initialValue: LoginFormCredentials(
        password: widget.initialPassword,
        username: widget.initialUsername,
      ),
      name: UserCredentialsFormField.fkCredentials,
      builder: (field) => Column(
        children: [
          TextFormField(
            key: const ValueKey('login-username'),
            focusNode: _usernameFocusNode,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (value) {
              _passwordFocusNode.requestFocus();
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            autocorrect: false,
            onChanged: (username) => field.didChange(
              field.value?.copyWith(username: username) ??
                  LoginFormCredentials(username: username),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return S.of(context)!.usernameMustNotBeEmpty;
              }
              final serverAddress = widget.formKey.currentState!
                  .getRawValue<String>(ServerAddressFormField.fkServerAddress);
              if (serverAddress != null) {
                final userExists = Hive.localUserAccountBox.values
                    .map((e) => e.id)
                    .contains('$value@$serverAddress');
                if (userExists) {
                  return S.of(context)!.userAlreadyExists;
                }
              }
              return null;
            },
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(label: Text(S.of(context)!.username)),
          ),
          SwitchListTile.adaptive(
            value: _useApiToken,
            onChanged: (value) {
              setState(() => _useApiToken = value);
              field.didChange(
                (field.value ?? LoginFormCredentials()).copyWith(
                  password: value ? '' : field.value?.password,
                  mfaCode: value ? '' : field.value?.mfaCode,
                  apiToken: value ? field.value?.apiToken ?? '' : '',
                ),
              );
            },
            title: Text(S.of(context)!.useApiTokenInsteadOfPassword),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          if (_useApiToken)
            ObscuredInputTextFormField(
              key: const ValueKey('login-api-token'),
              focusNode: _passwordFocusNode,
              label: S.of(context)!.apiToken,
              hintText: S.of(context)!.apiTokenRemoteUserHint,
              onChanged: (token) => field.didChange(
                (field.value ?? LoginFormCredentials()).copyWith(
                  apiToken: token,
                  password: '',
                  mfaCode: '',
                ),
              ),
              onFieldSubmitted: (_) {
                widget.onFieldsSubmitted?.call();
              },
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return S.of(context)!.apiTokenMustNotBeEmpty;
                }
                return null;
              },
            )
          else ...[
            ObscuredInputTextFormField(
              key: const ValueKey('login-password'),
              focusNode: _passwordFocusNode,
              label: S.of(context)!.password,
              onChanged: (password) => field.didChange(
                (field.value ?? LoginFormCredentials()).copyWith(
                  password: password,
                  apiToken: '',
                ),
              ),
              onFieldSubmitted: (_) {
                _mfaFocusNode.requestFocus();
              },
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return S.of(context)!.passwordMustNotBeEmpty;
                }
                return null;
              },
            ),
            TextFormField(
              key: const ValueKey('login-mfa-code'),
              focusNode: _mfaFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: (code) => field.didChange(
                (field.value ?? LoginFormCredentials()).copyWith(
                  mfaCode: code,
                  apiToken: '',
                ),
              ),
              onFieldSubmitted: (_) {
                widget.onFieldsSubmitted?.call();
              },
              decoration: InputDecoration(
                label: Text(S.of(context)!.mfaCodeOptional),
              ),
            ),
          ],
        ].map((child) => child.padded()).toList(),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/**
 * AutofillGroup(
      child: Column(
        children: [
          FormBuilderTextField(
            name: fkUsername,
            focusNode: _focusNodes[fkUsername],
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(_focusNodes[fkPassword]);
            },
            validator: FormBuilderValidators.required(
              errorText: S.of(context)!.usernameMustNotBeEmpty,
            ),
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              labelText: S.of(context)!.username,
            ),
          ).padded(),
          FormBuilderTextField(
            name: fkPassword,
            focusNode: _focusNodes[fkPassword],
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
            autofillHints: const [AutofillHints.password],
            validator: FormBuilderValidators.required(
              errorText: S.of(context)!.passwordMustNotBeEmpty,
            ),
            obscureText: true,
            decoration: InputDecoration(
              labelText: S.of(context)!.password,
            ),
          ).padded(),
        ],
      ),
    );
 */
