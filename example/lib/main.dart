import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'features/core/views/home_view.dart';

void main() {
  runApp(const MyApp());
}

class const MyApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const PlatformApp(title: 'better_internet_connectivity_checker example', home: HomeView());
}
