import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'double_up_overlay.dart';

/// The 5x3 centre panel of the board.
/// Shows: logo → message → doubling overlay.
class CenterDisplay extends ConsumerWidget {
  const CenterDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ──────────────
          Image.asset(
            'assets/images/slot_center_bg.png',
            fit: BoxFit.cover,
          ),

          // ── Doubling overlay ───────────────────────────────────────
          if (s.doublingActive) const DoubleUpOverlay(),
        ],
      ),
    );
  }
}
