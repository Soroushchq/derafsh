import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'intro/intro.dart';
import 'state/vpn_controller.dart';
import 'ui/home_screen.dart';
import 'ui/update_gate.dart';

/// Root widget: intro animation → mandatory-update gate → home.
class DerafshApp extends StatefulWidget {
  const DerafshApp({
    super.key,
    required this.controller,
    this.showIntro = true,
  });

  final VpnController controller;

  /// Exposed for widget tests so they can skip the intro.
  final bool showIntro;

  @override
  State<DerafshApp> createState() => _DerafshAppState();
}

class _DerafshAppState extends State<DerafshApp> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: buildDrafshTheme(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Stack(
        children: [
          MandatoryUpdateGate(
            child: HomeScreen(controller: widget.controller),
          ),
          if (widget.showIntro && !_introDone)
            IntroOverlay(onDone: () => setState(() => _introDone = true)),
        ],
      ),
    );
  }
}
