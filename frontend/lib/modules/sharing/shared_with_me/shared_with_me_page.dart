import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_api.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_state.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/note_card.dart';
import 'package:jotter/shared/widgets/note_collection.dart';
import 'package:jotter/shared/widgets/note_search_bar.dart';
import 'package:jotter/shared/widgets/permission_badge.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class SharedWithMePage extends StatefulWidget {
  const SharedWithMePage({super.key});

  @override
  State<SharedWithMePage> createState() => _SharedWithMePageState();
}

class _SharedWithMePageState extends State<SharedWithMePage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => SharedWithMeCubit(
      context.read<NoteStore>(),
      SharedWithMeApi(context.read<ApiNoteRepository>()),
    ),
    child: BlocBuilder<SharedWithMeCubit, SharedWithMeState>(
      builder: (context, state) {
        final cubit = context.read<SharedWithMeCubit>();
        final preferences = context.watch<PreferencesCubit>().state;
        final horizontal = context.isCompact ? 16.0 : 32.0;
        final notes = state.visible;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Shared with me',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        NoteSearchBar(
                          controller: _search,
                          onChanged: cubit.search,
                          hint: 'Search shared notes…',
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.loading && state.notes.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Refreshing shared notes',
                    ),
                  ),
                if (state.error != null && state.notes.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 16),
                    sliver: SliverToBoxAdapter(
                      child: MessageStrip(
                        state.error!,
                        error: true,
                        action: TextButton(
                          onPressed: cubit.refresh,
                          child: const Text('Retry'),
                        ),
                      ),
                    ),
                  ),
                if (state.loading && state.notes.isEmpty)
                  const SliverFillRemaining(child: LoadingView())
                else if (state.error != null && state.notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      message: state.error!,
                      onRetry: cubit.refresh,
                    ),
                  )
                else if (notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.people_outline_rounded,
                      title: state.query.isEmpty
                          ? 'Nothing shared with you yet'
                          : 'No shared notes match',
                      message: state.query.isEmpty
                          ? 'Notes other people share with you appear here.'
                          : 'Try another word.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    sliver: NoteCollectionSliver(
                      notes: notes,
                      listMode: preferences.listMode,
                      itemBuilder: (context, note) => NoteCard(
                        key: ValueKey(note.id),
                        note: note,
                        listMode: preferences.listMode,
                        color: preferences.noteColor,
                        onOpen: () => context.push(AppRoutes.note(note.id)),
                        footer: _SharedFooter(
                          info: state.info[note.id],
                          canEdit: note.canEdit,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _SharedFooter extends StatelessWidget {
  const _SharedFooter({required this.info, required this.canEdit});

  final SharedNoteInfo? info;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      PermissionBadge(canEdit: info?.canEdit ?? canEdit),
      if (info != null)
        Text(
          'From ${info!.sharedBy} · ${relativeDate(info!.sharedAt)}',
          style: TextStyle(fontSize: 11, color: context.jotterColors.muted),
        ),
    ],
  );
}
