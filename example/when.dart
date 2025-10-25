import 'package:flutter/material.dart';

class When extends StatelessWidget {
  const When({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("hello", selectionColor: Colors.red),
        ),
      ),
    );
  }
}
