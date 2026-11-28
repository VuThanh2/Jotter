import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_preferences.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_state.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/state_views.dart';

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
    subtitle:
        'Changes apply right away and follow your account to other '
        'devices.',
    icon: Icons.tune_rounded,
    fallbackRoute: AppRoutes.account,
    aside: BlocBuilder<PreferencesCubit, PreferencesState>(
      builder: (context, state) => _LivePreview(state: state),
    ),
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
            if (!context.isExpanded) ...[
              const SizedBox(height: 8),
              Text(
                'Changes apply right away and follow your account to other '
                'devices.',
                style: TextStyle(color: context.jotterColors.muted),
              ),
              const SizedBox(height: 20),
            ],
            _Section(
              title: 'Appearance',
              icon: Icons.palette_outlined,
              child:
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
            ),
            _Section(
              title: 'Note text size',
              icon: Icons.format_size_rounded,
              child: _FontSizeSlider(
                value: preferences.noteFontSize,
                onChanged: (size) =>
                    update((p) => p.copyWith(noteFontSize: size)),
              ),
            ),
            _Section(
              title: 'Note color',
              icon: Icons.format_color_fill_rounded,
              subtitle: 'New and existing cards use it as their background.',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (name, hex) in noteColors)
                    _ColorSwatch(
                      name: name,
                      hex: hex,
                      selected:
                          preferences.defaultNoteColor.toUpperCase() == hex,
                      onTap: () =>
                          update((p) => p.copyWith(defaultNoteColor: hex)),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Notes layout',
              icon: Icons.dashboard_outlined,
              child: SegmentedButton<String>(
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
            ),
            if (state.pendingSync) ...[
              const SizedBox(height: 4),
              const MessageStrip(
                'Saved on this device. Syncing to your account…',
                icon: Icons.cloud_upload_outlined,
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// One preference: a card with an icon, a title and its control.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
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
          const Text('A', style: TextStyle(fontSize: 12.5)),
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
          color: context.jotterColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.jotterColors.line),
        ),
        child: AnimatedDefaultTextStyle(
          duration: JotterMotion.fast,
          style: TextStyle(
            fontSize: _preview,
            height: 1.5,
            color: context.jotterColors.ink,
          ),
          child: const Text('A little room for your next thought.'),
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
          child: AnimatedContainer(
            duration: JotterMotion.fast,
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
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: JotterMotion.fast,
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.check_rounded,
                color: context.jotterColors.accent,
              ),
            ),
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

/// Desktop only: a sample note that follows the choices as they change.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.state});

  final PreferencesState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final color = state.noteColor == null
        ? (palette.dark ? palette.sidebar : palette.surface)
        : palette.tint(state.noteColor!);
    final muted = palette.muted;
    Widget line(double width) => FractionallySizedBox(
      widthFactor: width,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 8,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: palette.ink.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PREVIEW',
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: JotterMotion.medium,
          curve: JotterMotion.curve,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.ink.withValues(alpha: .08)),
            boxShadow: palette.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.push_pin_rounded, size: 15, color: palette.accent),
                  const Spacer(),
                  Icon(Icons.more_horiz_rounded, size: 18, color: muted),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Sunday plans',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: JotterMotion.fast,
                style: TextStyle(
                  fontFamily: kJotterFont,
                  fontSize: state.noteFontSize,
                  height: 1.55,
                  color: palette.ink,
                ),
                child: const Text(
                  'Coffee at the corner place, then a long walk with no '
                  'destination.',
                ),
              ),
              const SizedBox(height: 14),
              line(.9),
              line(.6),
              const SizedBox(height: 6),
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final (icon, label, value) in [
          (Icons.contrast_rounded, 'Theme', state.preferences.themeMode),
          (
            Icons.format_size_rounded,
            'Text size',
            '${state.noteFontSize.round()} px',
          ),
          (Icons.dashboard_outlined, 'Layout', state.preferences.listViewMode),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 17, color: muted),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(color: muted)),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
