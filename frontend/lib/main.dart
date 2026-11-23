import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/jotter_app.dart';

void main() {
  // Keeps browser back/forward and typed URLs in sync with the router.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const JotterApp());
}
