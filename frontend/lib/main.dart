import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/main_screen.dart';
import 'services/cache_service.dart'; // Импорт нового сервиса

// ВАЖНО: main теперь асинхронный (Future<void>)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локальной БД
  await CacheService.initHive();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  runApp(const MusicChordsApp());
}

class MusicChordsApp extends StatelessWidget {
  const MusicChordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const pastelPurple = Color(0xFFD0BCFF);

    final bool useGlassBackground = kIsWeb || (!kIsWeb && Platform.isIOS);
    final lightBg = useGlassBackground
        ? const Color(0xFFF2F2F7)
        : const Color(0xFFFDFDFD);
    final darkBg = useGlassBackground
        ? const Color(0xFF000000)
        : const Color(0xFF0F0F0F);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme =
            lightDynamic?.copyWith(brightness: Brightness.light) ??
            ColorScheme.fromSeed(
              seedColor: pastelPurple,
              brightness: Brightness.light,
            );
        ColorScheme darkScheme =
            darkDynamic?.copyWith(brightness: Brightness.dark) ??
            ColorScheme.fromSeed(
              seedColor: pastelPurple,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Chords Pro',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: lightScheme,
            scaffoldBackgroundColor: lightBg,
            textTheme: GoogleFonts.robotoTextTheme(ThemeData.light().textTheme),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: darkBg,
            textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}
