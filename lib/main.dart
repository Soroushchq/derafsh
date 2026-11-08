import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/strings.dart';
import 'data/admin_store.dart';
import 'data/drf_source.dart';
import 'data/node_resolver.dart';
import 'data/remote_config.dart';
import 'engine/libbox_engine.dart';
import 'engine/vpn_engine.dart';
import 'state/vpn_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // best-effort; never blocks startup
  unawaited(RuntimeConfig.refresh());

  final engine = _pickEngine();
  SourceCatalog catalog;
  try {
    catalog = await SourceCatalog.load();
  } catch (_) {
    catalog = SourceCatalog.empty();
  }

  final controller = VpnController(
    engine: engine,
    catalog: catalog,
    nodeResolver: SingBoxNodeResolver(),
    freeLimit: Config.freeDailyLimit,
    adminStore: PrefsAdminStore(),
  );
  runApp(DerafshApp(controller: controller));
}

VpnEngine _pickEngine() {
  if (Platform.isAndroid) {
    return LibboxVpnEngine();
  }
  return UnsupportedEngine(S.engineUnsupported);
}
