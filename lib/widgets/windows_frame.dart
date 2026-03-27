import 'package:flutter/material.dart';

class WindowsFrame extends StatelessWidget {
  final Widget child;

  const WindowsFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
    );
  }
}
