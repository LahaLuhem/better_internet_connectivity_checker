import 'package:better_internet_conn_check_example/home/home_view.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'Better internet connectivity checker example', home: const HomeView());
}
