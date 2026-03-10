import 'package:flutter/material.dart';

void main() {
  runApp(const BetterGuitarTunerApp());
}

class BetterGuitarTunerApp extends StatelessWidget {
  const BetterGuitarTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Guitar Tuner',
      home: Scaffold(
        appBar: AppBar(title: const Text('Better Guitar Tuner')),
        body: const Center(
          child: Text(
            'Project scaffold ready.\nPitch detection and platform integration are not implemented yet.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
