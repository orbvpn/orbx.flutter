// lib/presentation/screens/server_list/server_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/auth_provider.dart'; // ✅ This import is correct
import '../../../data/models/server.dart';
import 'widgets/server_card.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  String _searchQuery = '';
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    // Load servers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerProvider>().loadServers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Server'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ServerProvider>().refreshServers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search servers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Region filter chips
          _buildRegionFilter(),

          // Server list
          Expanded(
            child: Consumer<ServerProvider>(
              builder: (context, serverProvider, _) {
                if (serverProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (serverProvider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(serverProvider.errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            serverProvider.loadServers();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final servers = _filterServers(serverProvider.servers);

                if (servers.isEmpty) {
                  return const Center(child: Text('No servers found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    return ServerCard(
                      server: server,
                      onTap: () => _selectServer(server),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionFilter() {
    return Consumer<ServerProvider>(
      builder: (context, provider, _) {
        final regions = provider.servers.map((s) => s.country).toSet().toList()
          ..sort();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // "All" chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _selectedRegion == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedRegion = null;
                    });
                  },
                ),
              ),
              // Region chips
              ...regions.map((region) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(region),
                    selected: _selectedRegion == region,
                    onSelected: (_) {
                      setState(() {
                        _selectedRegion = region;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<OrbXServer> _filterServers(List<OrbXServer> servers) {
    return servers.where((server) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        if (!server.name.toLowerCase().contains(_searchQuery) &&
            !server.location.toLowerCase().contains(_searchQuery) &&
            !server.country.toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }

      // Filter by region
      if (_selectedRegion != null && server.country != _selectedRegion) {
        return false;
      }

      return true;
    }).toList();
  }

  void _selectServer(OrbXServer server) {
    final connectionProvider = context.read<ConnectionProvider>();
    final authProvider = context.read<AuthProvider>();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Server?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server: ${server.name}'),
            Text('Location: ${server.location}'),
            Text('Latency: ${server.latencyMs ?? 0}ms'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close server list

              // Get auth token from AuthProvider
              final authToken = authProvider.authToken;

              if (authToken == null || authToken.isEmpty) {
                // Show error if not authenticated
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Authentication required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              // Connect with auth token
              await connectionProvider.connect(
                server: server,
                authToken: authToken,
              );
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
