import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/models/sync_status.dart';

class SyncStatusCubit extends Cubit<WorkspaceSyncStatus> {
  SyncStatusCubit(this._source) : super(_source.value) {
    _source.addListener(_changed);
  }

  final ValueListenable<WorkspaceSyncStatus> _source;

  void _changed() {
    if (!isClosed) emit(_source.value);
  }

  @override
  Future<void> close() {
    _source.removeListener(_changed);
    return super.close();
  }
}
