import 'package:flutter/material.dart';
import 'package:simpleexpense/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.darkGray, title: Text('Home')),
      body: const Center(child: Text('Welcome to Simple Expense App!')),
    );
  }
}
