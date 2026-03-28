import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GolfSwingApp());
}

class GolfSwingApp extends StatelessWidget {
  const GolfSwingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golf Swing Analyzer',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
