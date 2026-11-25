import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_router.dart';
import 'package:jotter/app/session_scope.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/modules/profile/preferences/preferences_api.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_state.dart';
import 'package:jotter/modules/profile/preferences/preferences_store.dart';
import 'package:jotter/shared/lib/session.dart';

class JotterApp extends StatefulWidget {
  const JotterApp({super.key, this.sessionStore, this.openWorkspace});

  final SessionStore? sessionStore;
  final WorkspaceOpener? openWorkspace;

  @override
  State<JotterApp> createState() => _JotterAppState();
}

class _JotterAppState extends State<JotterApp> {
  late final SessionCubit _session = SessionCubit(
    widget.sessionStore ?? SecureSessionStore(),
    openWorkspace: widget.openWorkspace,
  )..restore();
  late final PreferencesCubit _preferences = PreferencesCubit(
    PreferencesStore(),
  );
  late final GoRouter _router = createAppRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _preferences.close();
    _session.close();
    super.dispose();
  }

  void _bindPreferences(BuildContext context, SessionState state) {
    _preferences.bind(
      state is SessionActive ? PreferencesApi(state.remote) : null,
    );
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: _session),
      BlocProvider.value(value: _preferences),
    ],
    child: BlocListener<SessionCubit, SessionState>(
      listener: _bindPreferences,
      child: BlocBuilder<PreferencesCubit, PreferencesState>(
        builder: (context, preferences) => MaterialApp.router(
          title: 'Jotter',
          debugShowCheckedModeBanner: false,
          theme: jotterTheme,
          darkTheme: jotterDarkTheme,
          themeMode: preferences.themeMode,
          routerConfig: _router,
          // Dialogs use the root navigator, so the session scope wraps it.
          builder: (context, child) => _SessionGate(child: child!),
        ),
      ),
    ),
  );
}

/// Provides the session scope to every route. After sign-out the old scope
/// stays one more frame so the page being left can still build.
class _SessionGate extends StatefulWidget {
  const _SessionGate({required this.child});

  final Widget child;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  OfflineNoteRepository? _workspace;

  @override
  void initState() {
    super.initState();
    _workspace = context.read<SessionCubit>().workspace;
  }

  void _sessionChanged(BuildContext context, SessionState state) {
    if (state is SessionActive) {
      setState(() => _workspace = state.workspace);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<SessionCubit>().workspace == null) {
        setState(() => _workspace = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<SessionCubit, SessionState>(
        listener: _sessionChanged,
        child: _workspace == null
            ? widget.child
            : SessionScope(workspace: _workspace!, child: widget.child),
      );
}
