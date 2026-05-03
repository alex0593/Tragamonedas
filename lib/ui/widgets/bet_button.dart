import 'package:flutter/material.dart';

import '../../data/symbols.dart';
import '../../theme/slot_theme.dart';

class BetButton extends StatelessWidget {
  final String type;
  final int count;
  final bool disabled;
  final bool isBetting;
  final VoidCallback onTap;

  const BetButton({
    super.key,
    required this.type,
    required this.count,
    required this.disabled,
    required this.isBetting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = symbolByType(type);
    final selected = count > 0;

    final baseColor = disabled
        ? const Color(0xFF6B7280)
        : selected
            ? SlotTheme.betSelected
            : SlotTheme.betBlue;

    final shadowColor = selected
        ? SlotTheme.betSelectedShadow
        : (disabled ? const Color(0xFF4A5568) : SlotTheme.betBlueShadow);

    final yOffset = selected ? 3.0 : 0.0;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Duration.zero,
              transform: Matrix4.translationValues(0, yOffset, 0),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBetting
                      ? SlotTheme.goldLight
                      : SlotTheme.betBlueLight,
                  width: isBetting ? 2 : 1,
                ),
                boxShadow: [
                  // Sombra base (3D profundidad)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: Offset(0, 8 - yOffset),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  // Sombra inferior (efecto borde)
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.8),
                    offset: Offset(0, 4 - yOffset),
                    blurRadius: 0,
                  ),
                  if (isBetting)
                    const BoxShadow(
                        color: Color(0xCCFDE047),
                        blurRadius: 12,
                        spreadRadius: 2),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              constraints: const BoxConstraints(minHeight: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Icon(symbol: symbol),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(
                      'x${symbol.prize}',
                      style: SlotTheme.gameFont(
                        size: 8,
                        color: SlotTheme.goldLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

class _Icon extends StatelessWidget {
  final GameSymbol symbol;
  const _Icon({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final iconName = symbol.baseType ?? symbol.type;
    return Image.asset(
      'assets/icons/$iconName.png',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
    );
  }
}
