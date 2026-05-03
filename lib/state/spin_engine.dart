import 'dart:math';

import '../data/light_path.dart';
import '../data/symbols.dart';

class SpinEngine {
  final Random _rng;
  SpinEngine([Random? rng]) : _rng = rng ?? Random();

  /// Build the 24-slot board with the exact symbol order from the
  /// "máquina mexicana" reference image (clockwise from top-left).
  List<GameSymbol> buildBoard() {
    const order = <String>[
      'orange',     //  0  top-left
      'bell',       //  1
      'bar',        //  2  BAR-500
      'bar1000',    //  3  BAR-1000
      'apple',      //  4
      'cherry',     //  5
      'plum',       //  6  top-right
      'watermelon', //  7
      'cherry',     //  8
      'once_more',  //  9  right centre
      'apple',      // 10
      'cherry',     // 11
      'orange',     // 12  bottom-right
      'bell',       // 13
      'cherry',     // 14
      'seven',      // 15
      'apple',      // 16
      'cherry',     // 17
      'plum',       // 18  bottom-left
      'star',       // 19
      'cherry',     // 20
      'once_more',  // 21  left centre
      'apple',      // 22
      'cherry',     // 23
    ];
    return [for (final t in order) kSymbols[t]!];
  }

  /// Compute delay (ms) for the next light step, replicating the HTML curve:
  ///   - Steps 0..9: speed decreases from 120 ms to topSpeed (30 ms), -10 each.
  ///   - Cruise.
  ///   - Last `slowdownSteps` (15): speed += 10 + (intoSlowdown * 2).
  static int stepDelayMs({
    required int currentStep,
    required int totalSteps,
    int initialSpeed = 120,
    int topSpeed = 30,
    int slowdownSteps = 18,  // Pasos de frenado más cortos y rápidos
  }) {
    int speed;
    // 1. Aceleración progresiva al inicio (Ramp-up)
    if (currentStep < 16) {
      speed = initialSpeed - ((initialSpeed - topSpeed) * (currentStep / 16)).round();
    } 
    // 2. Desaceleración progresiva al final (Ramp-down)
    else if (currentStep > totalSteps - slowdownSteps) {
      final intoSlowdown = currentStep - (totalSteps - slowdownSteps);
      // Freno suave hasta alcanzar 250ms
      speed = topSpeed + ((250 - topSpeed) * (intoSlowdown / slowdownSteps) * (intoSlowdown / slowdownSteps)).round();
    } 
    // 3. Velocidad crucero máxima
    else {
      speed = topSpeed;
    }
    return speed.clamp(20, 260);
  }

  int randomTotalSteps() => 96 + _rng.nextInt(3); 

  int randomSnakeSteps() => 60 + _rng.nextInt(20);

  int randomDoubleSteps() => 15 + _rng.nextInt(10);

  String pickSpecialEvent() {
    const events = ['snake', 'three_prizes', 'free_spin'];
    return events[_rng.nextInt(events.length)];
  }

  String pickDoubleWinner() => _rng.nextBool() ? 'left' : 'right';

  /// Returns up to 3 light-path indices (slot ids) where a prize can be paid
  /// (excludes once_more slots and slots without an active bet).
  List<int> pickThreePrizeTargets({
    required List<GameSymbol> board,
    required Map<String, int> selectedBets,
  }) {
    final candidates = <int>[];
    for (final slotId in kLightPath) {
      final s = board[slotId];
      if (s.isOnceMore) continue;
      if (s.prize == 0) continue;
      final bet = selectedBets[s.effectiveType] ?? 0;
      if (bet == 0) continue;
      candidates.add(slotId);
    }
    candidates.shuffle(_rng);
    return candidates.take(3).toList();
  }

  /// Resolve the snake's 3 cells (head + 2 trailing) given the final
  /// head position in the light path.
  List<int> snakePartsFromHead(int headLightIndex) {
    final n = kLightPath.length;
    return [
      headLightIndex,
      (headLightIndex - 1 + n) % n,
      (headLightIndex - 2 + n) % n,
    ];
  }

  /// Number of steps to reach a specific light index (always at least one
  /// full lap so the animation has visual weight).
  int stepsToTarget(int currentLightIndex, int targetLightIndex) {
    final n = kLightPath.length;
    var stepsToTarget = (targetLightIndex - currentLightIndex + n) % n;
    if (stepsToTarget == 0) stepsToTarget = n;
    return stepsToTarget + n * 2;
  }
}
