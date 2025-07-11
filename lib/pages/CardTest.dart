import 'package:flutter/material.dart';

class Cardtest extends StatelessWidget {
  Cardtest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Formula'), backgroundColor: Colors.blue),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.functions, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Formula Page',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'This is the formula testing page',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Expanded(
              child: buildTapCardList(5),
            ), // Change the number of cards as needed
          ],
        ),
      ),
    );
  }

  Widget buildTapCardList(int numberOfCards) {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: numberOfCards,
      itemBuilder: (context, index) {
        return Card(
          clipBehavior: Clip.hardEdge,
          margin: EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            splashColor: Colors.blue.withAlpha(30),
            onTap: () {
              debugPrint('Card #${index + 1} tapped.');
            },
            child: SizedBox(
              width: 300,
              height: 100,
              child: Center(child: Text('Card #${index + 1} - Tap me')),
            ),
          ),
        );
      },
    );
  }
}
