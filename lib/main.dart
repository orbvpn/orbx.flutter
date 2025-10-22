import 'package:flutter/material.dart';

void main() {
  runApp(const OrbVPNApp());
}

class OrbVPNApp extends StatelessWidget {
  const OrbVPNApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrbVPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OrbVPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // VPN Status Icon
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green : Colors.grey,
                boxShadow: [
                  BoxShadow(
                    color: (isConnected ? Colors.green : Colors.grey)
                        .withAlpha(128),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isConnected ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                size: 100,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 40),

            // Status Text
            Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            if (isConnected)
              Text(
                'Your connection is secure',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.green,
                    ),
              ),

            const SizedBox(height: 40),

            // Connect Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isConnected = !isConnected;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isConnected ? 'VPN Connected!' : 'VPN Disconnected',
                    ),
                    backgroundColor: isConnected ? Colors.green : Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 20,
                ),
                backgroundColor: isConnected ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isConnected ? 'Disconnect' : 'Connect',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Quick Stats
            if (isConnected)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        Icons.upload,
                        'Upload',
                        '1.2 MB',
                      ),
                      _buildStatItem(
                        context,
                        Icons.download,
                        'Download',
                        '3.5 MB',
                      ),
                      _buildStatItem(
                        context,
                        Icons.timer,
                        'Duration',
                        '5:32',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dns),
            label: 'Servers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tab $index clicked - Coming soon!'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
