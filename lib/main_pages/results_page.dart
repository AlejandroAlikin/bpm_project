import 'package:flutter/material.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<StatefulWidget> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text('Страница результатов'),
    );
  }
}