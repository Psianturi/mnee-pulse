import 'package:flutter/material.dart';

import 'screens/earn_screen.dart';
import 'screens/spend_screen.dart';

class MneePulseApp extends StatelessWidget {
  const MneePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNEE-Pulse',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const EarnScreen(),
      const SpendScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Earn',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            label: 'Spend',
          ),
        ],
      ),
    );
  }
}
