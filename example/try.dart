import 'package:flutter/material.dart';

import 'when.dart';
import 'new.dart';

class Try extends StatelessWidget {
  const Try({super.key});

  @override
  Widget build(BuildContext context) {
    //return Scaffold(body: Center(child: Text('Hello')));
    //return Container(child: Text("hello"));
    return Column(
      children: [
        Container(color: Colors.red, child: When()),
        Container(child: When()),
      ],
    );
  }
}
