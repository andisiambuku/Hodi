import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = Tokens.ink,
  });

  final String label;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Each tile is its own stop; without this they merge into one blob.
      container: true,
      label: context.l10n.statSemantics(label, value),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Tokens.s12),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          border: Border.all(color: Tokens.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value', style: Tokens.title.copyWith(color: valueColor)),
            Text(label, style: Tokens.caption),
          ],
        ),
      ),
    );
  }
}
