import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_state.dart';
import '../../state/providers.dart';

/// Action bar: COLLECT | ← | → | START
/// Layout mirrors the reference image.
class ActionButtons extends ConsumerWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s    = ref.watch(gameControllerProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);

    final canPlay  = s.totalSelectedBet > 0 && s.credits >= s.totalSelectedBet;
    final canRebet = s.totalSelectedBet == 0 &&
        s.totalLastBet > 0 &&
        s.credits >= s.totalLastBet;
    final isDouble   = s.canDouble;
    final playEnabled = !s.isBusy && (isDouble || canPlay || canRebet);

    final cashoutEnabled = s.doublingActive
        ? s.doubleResult == DoubleResult.none
        : (!s.isBusy && s.winnings > 0);
    final VoidCallback cashoutAction =
        s.doublingActive ? ctrl.cancelDoubleAndCashout : ctrl.cashout;

    // COLLECT button (very dark grey, like the image)
    final Widget collectBtn = _ArcadeButton(
      label: 'COLLECT',
      topColor: const Color(0xFF4B5563),
      bottomColor: const Color(0xFF1F2937),
      shadowColor: const Color(0xFF000000),
      textColor: Colors.white,
      enabled: cashoutEnabled,
      onTap: cashoutAction,
      flex: 2,
    );

    // ← arrow
    final Widget leftBtn = _ArcadeButton(
      icon: Icons.arrow_back_rounded,
      topColor: const Color(0xFF6B7280),
      bottomColor: const Color(0xFF374151),
      shadowColor: const Color(0xFF111827),
      textColor: Colors.white,
      enabled: !s.isBusy,
      onTap: ctrl.clearBetsAndHighlights,
      flex: 1,
    );

    // → arrow — repeats last bet
    final Widget rightBtn = _ArcadeButton(
      icon: Icons.arrow_forward_rounded,
      topColor: const Color(0xFF6B7280),
      bottomColor: const Color(0xFF374151),
      shadowColor: const Color(0xFF111827),
      textColor: Colors.white,
      enabled: !s.isBusy && s.totalLastBet > 0,
      onTap: () {
        if (s.credits >= s.totalLastBet && s.totalLastBet > 0) {
          ctrl.playOrDouble();
        }
      },
      flex: 1,
    );

    // START / DOBLAR / REPETIR button (green or purple)
    String startLabel;
    Color topGreen   = const Color(0xFF22C55E);
    Color botGreen   = const Color(0xFF15803D);
    Color shadowGreen = const Color(0xFF14532D);
    Color topColor;
    Color bottomColor;
    Color shadowC;
    if (isDouble) {
      startLabel = 'DOBLAR';
      topColor    = const Color(0xFF8B5CF6);
      bottomColor = const Color(0xFF6D28D9);
      shadowC     = const Color(0xFF4C1D95);
    } else if (canRebet) {
      startLabel = 'REPETIR';
      topColor   = topGreen; bottomColor = botGreen; shadowC = shadowGreen;
    } else {
      startLabel = 'START';
      topColor   = topGreen; bottomColor = botGreen; shadowC = shadowGreen;
    }

    final Widget startBtn = _ArcadeButton(
      label: startLabel,
      topColor: topColor,
      bottomColor: bottomColor,
      shadowColor: shadowC,
      textColor: Colors.white,
      enabled: playEnabled,
      onTap: ctrl.playOrDouble,
      flex: 2,
    );

    // When winning: DOBLAR left, COLLECT right
    final List<Widget> buttons = isDouble
        ? [startBtn, const SizedBox(width: 6), leftBtn, const SizedBox(width: 6), rightBtn, const SizedBox(width: 6), collectBtn]
        : [collectBtn, const SizedBox(width: 6), leftBtn, const SizedBox(width: 6), rightBtn, const SizedBox(width: 6), startBtn];

    return Row(children: buttons);
  }
}

class _ArcadeButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color topColor;
  final Color bottomColor;
  final Color shadowColor;
  final Color textColor;
  final bool enabled;
  final VoidCallback onTap;
  final int flex;

  const _ArcadeButton({
    this.label,
    this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.shadowColor,
    required this.textColor,
    required this.enabled,
    required this.onTap,
    this.flex = 1,
  });

  @override
  State<_ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<_ArcadeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    // Un botón mecánico baja físicamente al presionarlo, independientemente
    // de si el sistema electrónico lo ignora por estar deshabilitado.
    final physicalDown = _pressed;
    final double yOffset = physicalDown ? 12.0 : 0.0;
    final double bottomEdge = physicalDown ? 4.0 : 16.0;

    return Expanded(
      flex: widget.flex,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _pressed = true); // Baja físicamente
          if (!disabled) {
            // Botones grandes usan impacto medio (COLLECT, START) para
            // distinguirse claramente del "clic ligero" de los botones de apuesta.
            HapticFeedback.mediumImpact();
            widget.onTap();
          } else {
            // Botón bloqueado: vibración leve — el botón se hunde pero no hace nada.
            HapticFeedback.lightImpact();
          }
        },
        onTapUp: (_) => setState(() => _pressed = false), // Sube
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          color: Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          // Aquí aplicamos la matriz de transformación 3D real para inclinar
          // el botón hacia atrás, dándole esa forma trapezoidal (más angosto arriba)
          // que coincide exactamente con tu imagen POV.
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // Factor de perspectiva POV
              ..rotateX(-0.35),       // Inclinación hacia atrás (~20 grados)
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: Duration.zero,
                  top: yOffset,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    // La base blanca con gradiente para dar sombra cilíndrica/volumen
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: disabled
                            ? [
                                const Color(0xFF9CA3AF), // Gris más oscuro si está deshabilitado
                                const Color(0xFF6B7280),
                              ]
                            : [
                                const Color(0xFFFFFFFF), // Luz arriba
                                const Color(0xFF94A3B8), // Sombra en la base
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: disabled ? null : const [
                        BoxShadow(
                          color: Color(0x99000000),
                          offset: Offset(0, 8),
                          blurRadius: 6,
                        )
                      ]
                    ),
                    padding: EdgeInsets.only(
                      top: 2,
                      left: 3,
                      right: 3,
                      bottom: bottomEdge,
                    ),
                    child: Container(
                      // La cara superior metálica/color
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: disabled
                              ? [
                                  Color.lerp(const Color(0xFF4B5563), widget.topColor, 0.3)!,
                                  Color.lerp(const Color(0xFF4B5563), widget.topColor, 0.3)!,
                                  Color.lerp(const Color(0xFF374151), widget.bottomColor, 0.3)!,
                                  Color.lerp(const Color(0xFF374151), widget.bottomColor, 0.3)!,
                                ]
                              : [
                                  Color.lerp(Colors.white, widget.topColor, 0.3)!,
                                  widget.topColor,
                                  widget.bottomColor,
                                  Color.lerp(Colors.black, widget.bottomColor, 0.3)!,
                                ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: disabled 
                              ? Colors.white.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: widget.icon != null
                          ? Icon(widget.icon, color: disabled ? Colors.white54 : widget.textColor, size: 28)
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  widget.label!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: disabled ? Colors.white54 : widget.textColor,
                                    letterSpacing: 0.8,
                                    shadows: disabled ? null : const [
                                      Shadow(color: Color(0x88000000), offset: Offset(0, 1)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
