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
import 'presentation/screens/servers/server_list_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/statistics/stats_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';

class OrbXApp extends StatelessWidget {
  const OrbXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth Provider
        ChangeNotifierProvider(create: (_) => AuthProvider(getIt())),

        // Connection Provider
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(
            getIt(), // WireGuardService
            getIt(), // MimicryManager
            getIt(), // ServerRepository
          ),
        ),

        // Server Provider
        ChangeNotifierProvider(create: (_) => ServerProvider(getIt())),

        // Theme Provider
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'OrbVPN',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/servers': (context) => const ServerListScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/statistics': (context) => const StatisticsScreen(),
              '/profile': (context) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }
}
