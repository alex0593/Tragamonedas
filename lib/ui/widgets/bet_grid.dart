import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/symbols.dart';
import '../../state/providers.dart';
import 'led_display.dart';

/// Bottom bet panel — Mexican-arcade style:
///   Prize value (red) → symbol cell → 7-seg LED → big physical 3D button
class BetGrid extends ConsumerWidget {
  const BetGrid({super.key});

  // Order matches the reference image (left → right)
  static const List<String> _order = [
    'apple', 'watermelon', 'star', 'seven', 'bar',
    'bell', 'plum', 'orange', 'cherry',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s    = ref.watch(gameControllerProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);
    final disabled = s.isBusy || s.winnings > 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE67E00),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _order.asMap().entries.map((entry) {
          final idx = entry.key;
          final type = entry.value;
          final sym   = symbolByType(type);
          final count = s.selectedBets[type] ?? 0;
          return Expanded(
            child: _BetColumn(
              symbol: sym,
              count: count,
              disabled: disabled,
              onTap: () => ctrl.placeBet(type, idx),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BetColumn extends StatelessWidget {
  final GameSymbol symbol;
  final int count;
  final bool disabled;
  final VoidCallback onTap;

  const _BetColumn({
    required this.symbol,
    required this.count,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Prize value (red number) ─────────────────────────────
          FittedBox(
            child: Text(
              '${symbol.prize}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(height: 2),

          // ── Symbol cell (white box, sharp corners) ──────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFEF9C3) : Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF9CA3AF),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: AspectRatio(
              aspectRatio: 1,
              child: _SymbolIcon(symbol: symbol),
            ),
          ),
          const SizedBox(height: 3),

          // ── 7-segment LED counter ────────────────────────────────
          LedDisplay(value: count, height: 18),
          const SizedBox(height: 4),

          // ── Physical 3D arcade button ────────────────────────────
          _ArcadeBetButton(
            enabled: !disabled,
            pressed: selected,
            onTap: disabled ? null : onTap,
          ),
        ],
      ),
    );
  }
}

class _SymbolIcon extends StatelessWidget {
  final GameSymbol symbol;
  const _SymbolIcon({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final iconName = symbol.baseType ?? symbol.type;
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Image.asset(
        'assets/icons/$iconName.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Physical button styled like the round white plungers on Mexican
/// arcade slots. Has a clear "depressed" state when held / selected.
class _ArcadeBetButton extends StatefulWidget {
  final bool enabled;
  final bool pressed;
  final VoidCallback? onTap;

  const _ArcadeBetButton({
    required this.enabled,
    required this.pressed,
    required this.onTap,
  });

  @override
  State<_ArcadeBetButton> createState() => _ArcadeBetButtonState();
}

class _ArcadeBetButtonState extends State<_ArcadeBetButton> {
  bool _hold = false;

  @override
  Widget build(BuildContext context) {
    // Disabled → mismos colores, solo atenuados (NO parece "botón presionado").
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _hold = true);
          if (widget.enabled) {
            HapticFeedback.selectionClick();
            widget.onTap?.call();
          } else {
            HapticFeedback.lightImpact();
          }
        },
        onTapUp:     (_) => setState(() => _hold = false),
        onTapCancel: ()  => setState(() => _hold = false),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          // Transform(rotateX) da la forma trapezoidal / perspectiva POV
          // que da el aspecto 3D del botón visto desde arriba.
          // NOTA: el Transform va fuera del AnimatedContainer. Lo que
          // cambia con la animación es el padding-bottom (no la posición),
          // y AnimatedContainer anima el padding internamente — correctamente
          // incluso cuando el widget está dentro de un Transform.
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)  // factor de perspectiva POV
              ..rotateX(-0.35),        // inclinación ~20° (vista desde arriba)
            child: AnimatedContainer(
              duration: Duration.zero,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                // Cuerpo exterior del botón (base gris/blanca)
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFF94A3B8)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: _hold || !widget.enabled
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x77000000),
                          offset: Offset(0, 5),
                          blurRadius: 4,
                        ),
                      ],
              ),
              // padding-bottom crea el "pedestal" visible debajo de la cara.
              // UP  → bottom: 8  → cara elevada, pedestal expuesto abajo
              // DOWN → bottom: 1  → cara hunde, pedestal casi invisible
              padding: EdgeInsets.only(
                top: 1, left: 2, right: 2,
                bottom: _hold ? 1.0 : 8.0,
              ),
              child: Container(
                // Cara superior del botón (la parte que "baja")
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFF3F4F6),
                      Color(0xFFE5E7EB),
                      Color(0xFFD1D5DB),
                    ],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
