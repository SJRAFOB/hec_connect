import 'package:flutter/material.dart';

// Widget badge réutilisable pour toutes les sections
class BadgeWidget extends StatelessWidget {
  final Widget child;
  final int count;
  final Color color;
  final bool dot; // true = juste un point sans chiffre

  const BadgeWidget({
    super.key,
    required this.child,
    required this.count,
    this.color = Colors.red,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            padding: dot
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(dot ? 50 : 10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: dot
                ? null
                : Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ],
    );
  }
}
