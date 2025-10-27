import 'package:flutter/material.dart';

// import 'when.dart';
// import 'try.dart';

// class Hello extends StatelessWidget {
//   const Hello({super.key});

//   @override
//   Widget build(BuildContext context) {
//     //return Scaffold(body: Center(child: Text('Hello')));
//     //return Container(child: Text("hello"));
//     return ListView(
//       children: [
//         Container(color: Colors.red, child: When()),
//         Container(child: When()),
//       ],
//     );
//   }
// }

class Hello extends StatelessWidget {
  const Hello({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        child: Center(
          child: Align(
            child: Container(
              color: Colors.black,
              padding: EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  // child: Text("hello", selectionColor: Colors.white),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        color: Colors.red,
                        child: Text("hello1", selectionColor: Colors.white),
                      ),
                      Container(
                        child: Text("hello2", selectionColor: Colors.white),
                      ),
                    ],
                  ),
                  color: Colors.black,
                  padding: EdgeInsets.all(12),
                  alignment: Alignment.center,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  // decoration: BoxDecoration(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
