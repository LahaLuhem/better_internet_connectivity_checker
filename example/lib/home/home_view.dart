import 'package:better_internet_conn_check_example/home/home_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;
import 'package:pmvvm/mvvm_builder.widget.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: HomeViewModel(),
    viewBuilder: (context, viewMode) => Scaffold(body: Placeholder()),
  );
}
