import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/standby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape orientation only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive sticky: hide status bar and navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Keep screen awake indefinitely while the app is active
  WakelockPlus.enable();

  runApp(const StandbyDockApp());
}

class StandbyDockApp extends StatelessWidget {
  const StandbyDockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Standby Dock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E5FF),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        // Disable all Material splash/hover effects globally for cleaner look
        splashFactory: InkSparkle.splashFactory,
      ),
      home: const StandbyScreen(),
    );
  }
}
