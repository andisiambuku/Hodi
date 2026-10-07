import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/l10n.dart';

/// Four-tab bottom nav with an active dot, per the mockups.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.navVisits, l.navPatients, l.navSync, l.navProfile];
    return Container(
      decoration: const BoxDecoration(
        color: Tokens.surface,
        border: Border(top: BorderSide(color: Tokens.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == currentIndex,
                  label: labels[i],
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == currentIndex
                                  ? Tokens.primary
                                  : Tokens.navInactive,
                            ),
                          ),
                          const SizedBox(height: Tokens.s4),
                          Text(
                            labels[i],
                            style: Tokens.label.copyWith(
                              color: i == currentIndex
                                  ? Tokens.ink
                                  : Tokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
