import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'chat_app',
      initialRoute: '/',
      getPages: [],
      home: const Scaffold(
        body: Center(
          child: Text(
            '🚀 chat_app Initialized',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
