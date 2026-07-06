import 'package:flutter/material.dart';

class TagSelectionPage extends StatelessWidget {
  const TagSelectionPage({super.key});
  static const routeName = '/tags';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tags'),
      ),
      body: const Center(
        child: Text('Tag management coming soon'),
      ),
    );
  }
}