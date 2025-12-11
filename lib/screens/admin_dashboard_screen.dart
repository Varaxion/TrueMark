import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.construction, size: 64, color: Colors.indigo),
            SizedBox(height: 16),
            Text('Dashboard under maintenance', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Charts have been temporarily disabled.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}