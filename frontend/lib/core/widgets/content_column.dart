import 'package:flutter/material.dart';

/// Caps content width and centers it on wide viewports (the Windows
/// desktop build in particular) so forms/cards don't stretch edge to
/// edge; on narrow/mobile widths it's a no-op full-width column.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
