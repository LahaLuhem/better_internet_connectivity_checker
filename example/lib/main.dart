import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp;

import 'home/home_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'better_internet_connectivity_checker example', home: HomeView());
}
