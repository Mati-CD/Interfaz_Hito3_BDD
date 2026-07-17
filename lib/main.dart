import 'package:flutter/material.dart';
import 'package:interfaz_hito3_bdd/login_screen.dart';

void main() {
  runApp(const MegaElectricApp());
}

class MegaElectricApp extends StatelessWidget {
  const MegaElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mega Electric CMG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
