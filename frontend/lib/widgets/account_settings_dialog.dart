import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/account_api.dart';
import '../data/api_note_repository.dart';
import '../data/note_repository.dart';
import '../models/jotter_preferences.dart';
import 'account_dialog.dart';

Future<JotterPreferences?> showAccountSettingsDialog(
  BuildContext context, {
  required ApiNoteRepository repository,
  required JotterPreferences preferences,
  required ValueChanged<JotterPreferences> onPreferencesChanged,
}) => showDialog<JotterPreferences>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AccountSettings(
    repository: repository,
    preferences: preferences,
    onPreferencesChanged: onPreferencesChanged,
  ),
);

class _AccountSettings extends StatefulWidget {
  const _AccountSettings({
    required this.repository,
    required this.preferences,
    required this.onPreferencesChanged,
  });
  final ApiNoteRepository repository;
  final JotterPreferences preferences;
  final ValueChanged<JotterPreferences> onPreferencesChanged;
  @override
  State<_AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<_AccountSettings> {
  late final TextEditingController _name;
  late final TextEditingController _color;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _profileForm = GlobalKey<FormState>();
  final _preferencesForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late JotterPreferences _preferences;
  late JotterPreferences _savedPreferences;
  int _avatarGeneration = 0;
  Uint8List? _avatar;
  bool _busy = false;
  bool _showPasswords = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences;
    _savedPreferences = widget.preferences;
    _name = TextEditingController(text: widget.repository.account.displayName);
    _color = TextEditingController(text: _preferences.defaultNoteColor);
    _loadAvatar();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _color,
      _currentPassword,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final generation = _avatarGeneration;
    try {
      final bytes = await widget.repository.getAvatar();
      if (mounted && generation == _avatarGeneration)
        setState(() => _avatar = bytes);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Your profile photo could not be loaded.');
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await task();
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    await _run(() async {
      await widget.repository.updateProfile(_name.text);
      if (mounted) setState(() => _notice = 'Your profile has been updated.');
    });
  }

  Future<void> _chooseAvatar() async {
    await _run(() async {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Profile images',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      final size = await file.length();
      if (size <= 0 || size > 5 * 1024 * 1024)
        throw const RepositoryException('Choose an image smaller than 5 MB.');
      final bytes = await file.readAsBytes();
      _avatarGeneration++;
      await widget.repository.uploadAvatar(bytes, file.name);
      if (mounted)
        setState(() {
          _avatar = bytes;
          _notice = 'Your profile photo has been updated.';
        });
    });
  }

  Future<void> _removeAvatar() async => _run(() async {
    _avatarGeneration++;
    await widget.repository.removeAvatar();
    if (mounted)
      setState(() {
        _avatar = null;
        _notice = 'Your profile photo has been removed.';
      });
  });
  Future<void> _savePreferences() async {
    if (!_preferencesForm.currentState!.validate()) return;
    await _run(() async {
      final saved = await widget.repository.updatePreferences(
        _preferences.copyWith(defaultNoteColor: _color.text.toUpperCase()),
      );
      if (!mounted) return;
      setState(() {
        _preferences = saved;
        _savedPreferences = saved;
        _notice = 'Your preferences have been saved to your account.';
      });
      widget.onPreferencesChanged(saved);
    });
  }

  Future<void> _changePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    await _run(() async {
      await widget.repository.changePassword(
        _currentPassword.text,
        _newPassword.text,
        _confirmPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(
        () => _notice = 'Password changed. This device stays signed in; other devices will need to sign in again.',
      );
    });
  }

  Future<void> _activate() async {
    final result = await showActivationDialog(
      context,
      repository: widget.repository,
    );
    if (mounted && result == true)
      setState(() => _notice = 'Your email is confirmed.');
  }

  Widget _sectionTitle(String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 7),
        Text(
          description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
  Widget _profile() {
    final account = widget.repository.account;
    final initial = account.displayName.isEmpty
        ? 'J'
        : account.displayName.characters.first.toUpperCase();
    return _scroll(
      Form(
        key: _profileForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(
              'A little more you.',
              'Your name and photo appear when you share notes.',
            ),
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundImage: _avatar == null ? null : MemoryImage(_avatar!),
                child: Text(initial, style: const TextStyle(fontSize: 28)),
                onForegroundImageError: _avatar == null ? null : (_, _) {},
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseAvatar,
                  icon: const Icon(Icons.upload_rounded, size: 17),
                  label: const Text('Upload photo'),
                ),
                if (account.avatarUrl != null)
                  TextButton(
                    onPressed: _busy ? null : _removeAvatar,
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'JPEG, PNG, or WebP · Up to 5 MB',
                style: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              key: const Key('profile-name'),
              controller: _name,
              maxLength: 100,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your display name.'
                  : null,
            ),
            const SizedBox(height: 14),
            SelectableText(account.email, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  account.isActivated
                      ? Icons.verified_outlined
                      : Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    account.isActivated
                        ? 'Email confirmed'
                        : 'Email confirmation needed',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (!account.isActivated)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : _activate,
                  child: const Text('Confirm email'),
                ),
              ),
            const SizedBox(height: 25),
            FilledButton(
              onPressed: _busy ? null : _saveProfile,
              child: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appearance() => _scroll(
    Form(
      key: _preferencesForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Make yourself at home.',
            'Saved preferences follow your account across devices.',
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('theme-${_preferences.themeMode}'),
            initialValue: _preferences.themeMode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Theme'),
            items: const [
              DropdownMenuItem(
                value: 'System',
                child: Text('Use device setting'),
              ),
              DropdownMenuItem(value: 'Light', child: Text('Light')),
              DropdownMenuItem(value: 'Dark', child: Text('Dark')),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(
                    () =>
                        _preferences = _preferences.copyWith(themeMode: value),
                  ),
          ),
          const SizedBox(height: 22),
          Text(
            'Note text size · ${_preferences.noteFontSize}px',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _preferences.noteFontSize.clamp(12, 32).toDouble(),
            min: 12,
            max: 32,
            divisions: 20,
            label: '${_preferences.noteFontSize}px',
            onChanged: _busy
                ? null
                : (value) => setState(
                    () => _preferences = _preferences.copyWith(
                      noteFontSize: value.round(),
                    ),
                  ),
          ),
          Text(
            'A little room for your next thought.',
            style: TextStyle(
              fontSize: _preferences.noteFontSize.toDouble(),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            key: const Key('default-note-color'),
            controller: _color,
            enabled: !_busy,
            maxLength: 7,
            decoration: const InputDecoration(
              labelText: 'Default note color',
              hintText: '#FFFFFF',
            ),
            validator: (value) =>
                RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value ?? '')
                ? null
                : 'Use a color such as #FFFFFF.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, hex) in [
                ('Paper', '#FFFFFF'),
                ('Sand', '#F4EEDC'),
                ('Sage', '#EAF0E6'),
                ('Peach', '#F6E7DF'),
                ('Lavender', '#EEEAF3'),
              ])
                ActionChip(
                  label: Text(name),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _color.text = hex;
                          _preferences = _preferences.copyWith(
                            defaultNoteColor: hex,
                          );
                        }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            key: ValueKey('view-${_preferences.listViewMode}'),
            initialValue: _preferences.listViewMode,
            decoration: const InputDecoration(
              labelText: 'Default notes layout',
            ),
            items: const [
              DropdownMenuItem(value: 'Grid', child: Text('Grid')),
              DropdownMenuItem(value: 'List', child: Text('List')),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(
                    () => _preferences = _preferences.copyWith(
                      listViewMode: value,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _savePreferences,
            child: const Text('Save preferences'),
          ),
        ],
      ),
    ),
  );

  Widget _security() => _scroll(
    Form(
      key: _passwordForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Keep your thoughts yours.',
            'Changing your password signs out other devices.',
          ),
          _passwordField(
            _currentPassword,
            'Current password',
            const Key('current-password'),
          ),
          const SizedBox(height: 17),
          _passwordField(
            _newPassword,
            'New password',
            const Key('new-password'),
          ),
          const SizedBox(height: 17),
          _passwordField(
            _confirmPassword,
            'Confirm new password',
            const Key('confirm-new-password'),
            confirm: true,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _showPasswords,
            onChanged: _busy
                ? null
                : (value) => setState(() => _showPasswords = value ?? false),
            title: const Text('Show passwords', style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Text(
            'Use uppercase and lowercase letters, a number, and a symbol. Your new password must differ from the current one.',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _changePassword,
            child: const Text('Change password'),
          ),
        ],
      ),
    ),
  );
  Widget _passwordField(
    TextEditingController controller,
    String label,
    Key key, {
    bool confirm = false,
  }) => TextFormField(
    key: key,
    controller: controller,
    enabled: !_busy,
    obscureText: !_showPasswords,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      controller == _currentPassword
          ? AutofillHints.password
          : AutofillHints.newPassword,
    ],
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (value == null || value.isEmpty)
        return 'Enter ${label.toLowerCase()}.';
      if (confirm && value != _newPassword.text)
        return 'The passwords do not match.';
      if (controller == _newPassword && value == _currentPassword.text)
        return 'Choose a different new password.';
      return null;
    },
  );
  Widget _scroll(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 25, 24, 25),
    child: child,
  );
  Widget _banner() => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      color: _error != null
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Text(
        _error ?? _notice ?? '',
        style: TextStyle(
          fontSize: 12,
          color: _error != null
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: DefaultTabController(
      length: 3,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Account settings',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close settings',
                        onPressed: _busy
                            ? null
                            : () => Navigator.pop(context, _savedPreferences),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                const TabBar(
                  tabs: [
                    Tab(text: 'Profile'),
                    Tab(text: 'Appearance'),
                    Tab(text: 'Security'),
                  ],
                ),
                if (_error != null || _notice != null) _banner(),
                Expanded(
                  child: TabBarView(
                    children: [_profile(), _appearance(), _security()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
