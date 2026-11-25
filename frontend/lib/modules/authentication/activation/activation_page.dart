import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/authentication/activation/activation_api.dart';
import 'package:jotter/modules/authentication/activation/activation_cubit.dart';
import 'package:jotter/modules/authentication/activation/activation_state.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/shared/models/submit_state.dart';
import 'package:jotter/shared/widgets/otp_input.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class ActivationPage extends StatelessWidget {
  const ActivationPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        ActivationCubit(ActivationApi(context.read<ApiNoteRepository>())),
    child: const _ActivationView(),
  );
}

class _ActivationView extends StatefulWidget {
  const _ActivationView();

  @override
  State<_ActivationView> createState() => _ActivationViewState();
}

class _ActivationViewState extends State<_ActivationView> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      context.read<ActivationCubit>().confirm(_code.text);
    }
  }

  void _onSuccess(BuildContext context, ActivationState state) {
    context.read<MeCubit>().accountUpdated(state.result!);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Your email is confirmed.')));
    context.canPop() ? context.pop() : context.go(AppRoutes.notes);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ActivationCubit>();
    return PageFrame(
      title: 'Confirm your email',
      fallbackRoute: AppRoutes.account,
      maxWidth: 440,
      child: BlocConsumer<ActivationCubit, ActivationState>(
        listenWhen: (_, state) => state.isSuccess,
        listener: _onSuccess,
        builder: (context, state) {
          final busy = state.isSubmitting || state.isSuccess;
          return Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Enter the six-digit code we sent to ${cubit.email}. '
                  'You can keep using Jotter while you wait for it.',
                  style: const TextStyle(height: 1.55),
                ),
                const SizedBox(height: 24),
                OtpInput(
                  key: const Key('activation-code'),
                  controller: _code,
                  label: 'Activation code',
                  enabled: !busy,
                  onCompleted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ResendCodeButton(
                    onResend: cubit.resend,
                    onSent: _code.clear,
                  ),
                ),
                if (state.status == SubmitStatus.failure) ...[
                  MessageStrip(state.error!, error: true),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  key: const Key('activation-submit'),
                  onPressed: busy ? null : _submit,
                  child: Text(busy ? 'Confirming…' : 'Confirm email'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
