import 'package:flutter/material.dart';

class PlantPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const PlantPage(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: children,
          ),
        ),
      ),
    ),
  );
}
