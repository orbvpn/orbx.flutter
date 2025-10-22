import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/di/injection.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/connection_provider.dart';
import 'presentation/providers/server_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';

class OrbXApp extends StatelessWidget {
  const OrbXApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(getIt()),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(
            getIt(),
            getIt(),
            getIt(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ServerProvider(getIt()),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'OrbVPN',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
