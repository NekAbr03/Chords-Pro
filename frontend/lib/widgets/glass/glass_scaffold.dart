import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final String? title;

  const GlassScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Abstract fluid background
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // 1. Background (Gradient / Wallpaper)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8E2DE2), // Purple
                  Color(0xFF4A00E0), // Deep Purple
                  Color(0xFF00C6FF), // Blue
                ],
              ),
            ),
          ),

          // 2. Content
          Positioned.fill(child: SafeArea(bottom: false, child: body)),

          // 3. Floating Bottom Bar (if present)
          if (bottomNavigationBar != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 34, // Safe area + margin
              child: bottomNavigationBar!,
            ),
        ],
      ),
    );
  }
}
