import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config.dart';
import 'engine/vpn_engine.dart';
import 'state/vpn_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  final controller = VpnController(
    engine: StubVpnEngine(),
    freeDailyLimit: Config.freeDailyLimit,
  );
  runApp(DerafshApp(controller: controller));
}
