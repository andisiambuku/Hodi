import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AvatarInitial extends StatelessWidget {
  const AvatarInitial({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Tokens.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: Tokens.bodyStrong.copyWith(color: Tokens.primary),
        ),
      ),
    );
  }
}
