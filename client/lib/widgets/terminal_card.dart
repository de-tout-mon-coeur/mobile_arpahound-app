import 'package:flutter/material.dart';
import '../app_theme.dart';

class TerminalCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const TerminalCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              color: AppTheme.greenDark,
              child: Text(
                '[ $title ]',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.green,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
