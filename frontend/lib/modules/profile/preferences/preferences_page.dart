import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_preferences.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_state.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/shared/widgets/page_frame.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  static const noteColors = [
    ('Paper', '#FFFFFF'),
    ('Sand', '#F4EEDC'),
    ('Sage', '#EAF0E6'),
    ('Peach', '#F6E7DF'),
    ('Lavender', '#EEEAF3'),
    ('Sky', '#E4EEF5'),
  ];

  @override
  Widget build(BuildContext context) => PageFrame(
    banner: const UnverifiedBanner(),
    title: 'Preferences',
    fallbackRoute: AppRoutes.account,
    child: BlocBuilder<PreferencesCubit, PreferencesState>(
      builder: (context, state) {
        final cubit = context.read<PreferencesCubit>();
        final preferences = state.preferences;
        // Reads the cubit at call time so quick successive edits never
        // overwrite each other with a stale snapshot from the last build.
        void update(JotterPreferences Function(JotterPreferences) edit) =>
            cubit.update(edit(cubit.state.preferences));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Changes apply right away and follow your account to other devices.',
              style: TextStyle(color: context.jotterColors.muted),
            ),
            const _Heading('Appearance'),
            // On narrow phones three icon+label segments would break
            // "System" mid-word, so icons give way to the labels there.
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 340;
                return SegmentedButton<String>(
                  key: const Key('theme-mode'),
                  showSelectedIcon: !compact,
                  segments: [
                    ButtonSegment(
                      value: 'System',
                      label: const _OneLine('System'),
                      icon: compact
                          ? null
                          : const Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: 'Light',
                      label: const _OneLine('Light'),
                      icon: compact
                          ? null
                          : const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: 'Dark',
                      label: const _OneLine('Dark'),
                      icon: compact
                          ? null
                          : const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {preferences.themeMode},
                  onSelectionChanged: (value) =>
                      update((p) => p.copyWith(themeMode: value.single)),
                );
              },
            ),
            const _Heading('Note text size'),
            _FontSizeSlider(
              value: preferences.noteFontSize,
              onChanged: (size) =>
                  update((p) => p.copyWith(noteFontSize: size)),
            ),
            const _Heading('Note color'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (name, hex) in noteColors)
                  _ColorSwatch(
                    name: name,
                    hex: hex,
                    selected: preferences.defaultNoteColor.toUpperCase() == hex,
                    onTap: () =>
                        update((p) => p.copyWith(defaultNoteColor: hex)),
                  ),
              ],
            ),
            const _Heading('Notes layout'),
            SegmentedButton<String>(
              key: const Key('layout-mode'),
              segments: const [
                ButtonSegment(
                  value: 'Grid',
                  label: Text('Grid'),
                  icon: Icon(Icons.grid_view_rounded),
                ),
                ButtonSegment(
                  value: 'List',
                  label: Text('List'),
                  icon: Icon(Icons.view_agenda_outlined),
                ),
              ],
              selected: {preferences.listViewMode},
              onSelectionChanged: (value) =>
                  update((p) => p.copyWith(listViewMode: value.single)),
            ),
            if (state.pendingSync) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: context.jotterColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved on this device. Syncing to your account…',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.jotterColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _FontSizeSlider extends StatefulWidget {
  const _FontSizeSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_FontSizeSlider> createState() => _FontSizeSliderState();
}

class _FontSizeSliderState extends State<_FontSizeSlider> {
  late double _preview = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant _FontSizeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _preview = widget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Text('A', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Slider(
              key: const Key('font-size'),
              value: _preview.clamp(12, 32),
              min: 12,
              max: 32,
              divisions: 20,
              label: '${_preview.round()}',
              // Saves once the thumb is released instead of on every step.
              onChanged: (value) => setState(() => _preview = value),
              onChangeEnd: (value) => widget.onChanged(value.round()),
            ),
          ),
          const Text('A', style: TextStyle(fontSize: 22)),
        ],
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.jotterColors.sidebar,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'A little room for your next thought.',
          style: TextStyle(fontSize: _preview, height: 1.5),
        ),
      ),
    ],
  );
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.name,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.jotterColors.tint(
      Color(int.parse('FF${hex.substring(1)}', radix: 16)),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '$name note color',
      excludeSemantics: true,
      child: Tooltip(
        message: name,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? JotterColors.accent
                    : context.jotterColors.line,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: JotterColors.accent)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Shrinks a segment label to fit rather than breaking it mid-word.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}
