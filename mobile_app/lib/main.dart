import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const GSMApp(),
    ),
  );
}

class GSMApp extends StatelessWidget {
  const GSMApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'Vigil',
      themeMode: appProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0E14), // Deep dark blue/black for "trading" look
        ),
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        scaffoldBackgroundColor: const Color(0xFF050505),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E14),
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
