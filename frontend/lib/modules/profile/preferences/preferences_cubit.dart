import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/models/jotter_preferences.dart';
import 'package:jotter/modules/profile/preferences/preferences_api.dart';
import 'package:jotter/modules/profile/preferences/preferences_state.dart';
import 'package:jotter/modules/profile/preferences/preferences_store.dart';

/// Lives for the whole app because the theme sits above the router.
class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit(this._store) : super(const PreferencesState());

  final PreferencesStore _store;
  PreferencesApi? _api;

  Future<void> bind(PreferencesApi? api) async {
    _api = api;
    if (api == null) {
      emit(const PreferencesState());
      return;
    }
    final cached = await _store.read(api.accountId);
    if (cached != null && identical(api, _api)) {
      emit(
        PreferencesState(
          preferences: cached.preferences,
          pendingSync: cached.pending,
        ),
      );
    }
    if (cached?.pending ?? false) {
      await _push(cached!.preferences);
    } else {
      await _pull();
    }
  }

  /// Applies immediately; the server copy follows when it can be reached.
  Future<void> update(JotterPreferences preferences) async {
    final api = _api;
    emit(PreferencesState(preferences: preferences, pendingSync: true));
    if (api == null) return;
    await _store.write(api.accountId, preferences, pending: true);
    await _push(preferences);
  }

  Future<void> _pull() async {
    final api = _api;
    if (api == null) return;
    try {
      final remote = await api.fetch();
      if (!identical(api, _api) || isClosed) return;
      emit(PreferencesState(preferences: remote));
      await _store.write(api.accountId, remote, pending: false);
    } catch (_) {
      // Offline: the cached preferences stay in effect.
    }
  }

  Future<void> _push(JotterPreferences preferences) async {
    final api = _api;
    if (api == null) return;
    try {
      final saved = await api.save(preferences);
      if (!identical(api, _api) || isClosed) return;
      // A newer local change made while this request ran must win.
      if (!identical(state.preferences, preferences)) return;
      emit(PreferencesState(preferences: saved));
      await _store.write(api.accountId, saved, pending: false);
    } catch (_) {
      // Stays pending and is retried on the next start.
    }
  }
}
