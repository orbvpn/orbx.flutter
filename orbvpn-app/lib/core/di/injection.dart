import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../data/api/graphql/client.dart';
import '../services/wireguard_service.dart';
import '../services/mimicry_manager.dart';
import '../services/network_analyzer.dart';
import '../services/notification_service.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Storage
  getIt.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());

  // API Clients
  getIt.registerSingleton<GraphQLService>(GraphQLService.instance);

  // Services
  getIt.registerSingleton<NetworkAnalyzer>(NetworkAnalyzer());

  getIt.registerSingleton<NotificationService>(NotificationService());

  // Repositories
  getIt.registerSingleton<AuthRepository>(AuthRepository());

  getIt.registerSingleton<ServerRepository>(
    ServerRepository(getIt<NetworkAnalyzer>()),
  );

  // VPN Services
  getIt.registerSingleton<WireGuardService>(
    WireGuardService(getIt<AuthRepository>()),
  );

  getIt.registerSingleton<MimicryManager>(
    MimicryManager(getIt<AuthRepository>()),
  );

  // Initialize notification service
  await getIt<NotificationService>().initialize();
}
