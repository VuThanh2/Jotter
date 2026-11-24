import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/profile/shared/me_state.dart';
import 'package:jotter/shared/widgets/user_avatar.dart';

/// The avatar button that opens the account screen.
class AccountEntry extends StatelessWidget {
  const AccountEntry({super.key, this.radius = 16});

  final double radius;

  @override
  Widget build(BuildContext context) => BlocBuilder<MeCubit, MeState>(
    builder: (context, state) => IconButton(
      key: const Key('account-entry'),
      tooltip: 'Account · ${state.account.displayName}',
      onPressed: () => context.push(AppRoutes.account),
      icon: UserAvatar(
        name: state.account.displayName,
        image: state.avatar,
        radius: radius,
      ),
    ),
  );
}
