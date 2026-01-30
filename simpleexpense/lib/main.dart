import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SimpleExpense(title: 'Simple Expense'),
    );
  }
}

class SimpleExpense extends StatefulWidget {
  SimpleExpense({super.key, required this.title});

  final String title;

  @override
  State<SimpleExpense> createState() => _SimpleExpenseState();
}

class _SimpleExpenseState extends State<SimpleExpense> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const Center(child: Text('Welcome to Simple Expense App!')),
    );
  }
}
