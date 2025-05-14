import 'package:flutter/material.dart';

class ChatBotPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ChatBot AI')),
      body: Center(
        child: Text(
          'Chào bạn! Tôi là trợ lý ảo ChatBot 👋',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
