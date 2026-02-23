// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'services/receipt_printer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register WebUSB cash drawer functions (Web only)
  if (kIsWeb) {
    ReceiptPrinter.initCashDrawer();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniMart POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansLao'),
      home: const LoginPage(),
    );
  }
}
