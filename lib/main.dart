import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge to edge: the felt paints behind transparent system bars (#81).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(systemBars);
  runApp(const HonestSolitaireApp());
}
