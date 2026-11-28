import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/local_workspace_store.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/shared/me_api.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_api.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_store.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_cubit.dart';
import 'package:jotter/shared/lib/session.dart';

/// Everything tied to one signed-in account. Rebuilt from scratch per account.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.workspace, required this.child});

  final OfflineNoteRepository workspace;
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    key: ObjectKey(workspace),
    providers: [
      RepositoryProvider.value(value: workspace),
      RepositoryProvider<ApiNoteRepository>.value(value: workspace.remote),
      RepositoryProvider(create: (_) => NoteStore(workspace)),
      RepositoryProvider(create: (_) => LabelStore(workspace)),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => MeCubit(
            MeApi(workspace.remote),
            onAccountChanged: context.read<SessionCubit>().accountChanged,
          )..refresh(),
        ),
        BlocProvider(create: (_) => SyncStatusCubit(workspace.syncStatus)),
        BlocProvider(
          create: (context) => ShareInboxCubit(
            context.read<NoteStore>(),
            SharedWithMeApi(workspace.remote),
            SharedWithMeStore(
              PreferencesWorkspaceStore(),
              accountId: workspace.remote.account.id,
            ),
          )..start(),
        ),
      ],
      child: child,
    ),
  );
}
