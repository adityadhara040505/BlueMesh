import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/local/hive_boxes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent Hive storage before rendering any widgets
  try {
    await HiveBoxes.init();
  } catch (e, stack) {
    debugPrint('HiveBoxes.init() error in main: $e\n$stack');
  }

  // Lock status bar / navigation bar system UI overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: BlueMeshApp(),
    ),
  );
}
