import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/slot_theme.dart';
import 'ui/screens/slot_screen.dart';


class TragamonedasApp extends ConsumerWidget {
  const TragamonedasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return MaterialApp(
      title: 'Tragamonedas — Super Alianza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: SlotTheme.bgOuter,
        brightness: Brightness.dark,
        useMaterial3: false,
        fontFamily: 'RobotoCondensed',
      ),
      home: const SlotScreen(),
    );
  }
}
