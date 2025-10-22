import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../data/api/graphql/client.dart';
import '../services/wireguard_service.dart';
import '../services/mimicry_manager.dart';
import '../services/network_analyzer.dart';
import '../services/notification_service.dart';

final getIt = GetIt.instance;
final Logger _logger = Logger();

Future<void> setupDependencies() async {
  _logger.i('Setting up dependencies...');

  try {
    // Storage
    getIt.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());
    _logger.i('✅ Secure storage registered');

    // Initialize GraphQL client FIRST
    await GraphQLService.instance.initialize();
    getIt.registerSingleton<GraphQLService>(GraphQLService.instance);
    _logger.i('✅ GraphQL service registered');

    // Services
    getIt.registerSingleton<NetworkAnalyzer>(NetworkAnalyzer());
    _logger.i('✅ Network analyzer registered');

    // Notification service (completely optional - isolate its errors)
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      getIt.registerSingleton<NotificationService>(notificationService);
      _logger.i('✅ Notification service registered');
    } catch (e) {
      _logger.w('⚠️ Notification service unavailable: $e');
      // Register a dummy instance so app doesn't crash
      getIt.registerSingleton<NotificationService>(NotificationService());
      _logger.i('✅ Notification service registered (disabled)');
    }

    // CRITICAL SERVICES - These must succeed
    // Repositories - Pass dependencies explicitly
    getIt.registerSingleton<AuthRepository>(
      AuthRepository(
        graphQLService: getIt<GraphQLService>(),
        secureStorage: getIt<FlutterSecureStorage>(),
      ),
    );
    _logger.i('✅ Auth repository registered');

    getIt.registerSingleton<ServerRepository>(
      ServerRepository(getIt<NetworkAnalyzer>()),
    );
    _logger.i('✅ Server repository registered');

    // VPN Services
    getIt.registerSingleton<WireGuardService>(
      WireGuardService(getIt<AuthRepository>()),
    );
    _logger.i('✅ WireGuard service registered');

    getIt.registerSingleton<MimicryManager>(
      MimicryManager(getIt<AuthRepository>()),
    );
    _logger.i('✅ Mimicry manager registered');

    _logger.i('🎉 All core dependencies registered successfully');
  } catch (e, stackTrace) {
    _logger.e('❌ CRITICAL: Failed to register core dependencies: $e');
    _logger.e('Stack trace: $stackTrace');
    rethrow; // This is a real error - app can't work without these
  }
}
