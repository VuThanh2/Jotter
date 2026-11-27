import 'package:flutter/material.dart';
import 'package:jotter/shared/widgets/jotter_mark.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: EntranceTransition(
        scale: .9,
        offset: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JotterMark(size: 40),
            SizedBox(height: 30),
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                strokeCap: StrokeCap.round,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
