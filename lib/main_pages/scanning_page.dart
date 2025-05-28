import 'package:flutter/material.dart';

class ScanningPage extends StatefulWidget {
  const ScanningPage({super.key});

  @override
  State<StatefulWidget> createState() => _ScanningPageState();
}

class _ScanningPageState extends State<ScanningPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text('Страница сканирования'),
    );
  }
}