import 'package:flutter/widgets.dart';

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateRequired(String? value, String what) =>
    value == null || value.trim().isEmpty ? 'Enter $what.' : null;

FormFieldValidator<String> validateConfirmation(String Function() original) =>
    (value) {
      if (value == null || value.isEmpty) return 'Enter the password again.';
      return value == original() ? null : 'The passwords do not match.';
    };

const passwordHint =
    'At least 6 characters with upper and lower case letters, a number and a symbol.';
