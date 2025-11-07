import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddFabButton extends StatelessWidget {
  const AddFabButton({
    super.key,
    required this.onTap,
    this.heroTag,
  });

  final VoidCallback onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        heroTag: heroTag ?? 'addFab',
        onPressed: onTap,
        elevation: 8,
        backgroundColor: const Color(0xFF4F9BFF),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }
}
