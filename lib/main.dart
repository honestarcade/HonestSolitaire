import 'package:flutter/material.dart';

void main() {
  runApp(const HonestSolitaireApp());
}

/// The scaffold's placeholder: a branded start screen, so the gate's build
/// and bundle scan have a real app to work on until the game lands.
class HonestSolitaireApp extends StatelessWidget {
  const HonestSolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Honest Solitaire',
      debugShowCheckedModeBanner: false,
      home: PlaceholderScreen(),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  static const navy = Color(0xFF05285F);
  static const teal = Color(0xFF00D6B4);
  static const mist = Color(0xFF7FA6D8);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Honest',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'Solitaire',
                    style: TextStyle(color: teal),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 14),
            Text(
              'BY HONEST ARCADE',
              style: TextStyle(
                color: mist,
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
