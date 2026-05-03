import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/credits_dao.dart';
import '../data/db/stats_dao.dart';
import '../data/light_path.dart';
import '../util/sound_service.dart';
import 'game_state.dart';
import 'spin_engine.dart';

class GameController extends StateNotifier<GameState> {
  GameController({
    required CreditsDao creditsDao,
    required StatsDao statsDao,
    required SpinEngine engine,
    required int initialCredits,
  })  : _creditsDao = creditsDao,
        _statsDao = statsDao,
        _engine = engine,
        super(GameState.initial(
          credits: initialCredits,
          board: engine.buildBoard(),
        ));

  final CreditsDao _creditsDao;
  final StatsDao _statsDao;
  final SpinEngine _engine;

  Timer? _stepTimer;

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  // ───────────────────────── Reward ───────────────────────────────

  static const int _rewardAmount = 100;
  static const Duration _rewardCooldown = Duration(minutes: 5);

  /// Returns true if the reward button is currently available.
  bool get canClaimReward {
    final last = state.lastRewardClaimed;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _rewardCooldown;
  }

  /// Returns how many seconds remain until the reward is available again.
  int get rewardCooldownSeconds {
    final last = state.lastRewardClaimed;
    if (last == null) return 0;
    final elapsed = DateTime.now().difference(last);
    final remaining = _rewardCooldown - elapsed;
    return remaining.inSeconds.clamp(0, _rewardCooldown.inSeconds);
  }

  void claimReward() {
    if (!canClaimReward) return;
    final newCredits = state.credits + _rewardAmount;
    soundService.play(SoundEffect.cashout);
    state = state.copyWith(
      credits: newCredits,
      lastRewardClaimed: DateTime.now(),
      flashCredits: true,
    );
    _persistCredits();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      state = state.copyWith(flashCredits: false);
    });
  }

  // ───────────────────────────── Bets ─────────────────────────────

  static const int _maxBetPerSymbol = 10;

  void placeBet(String type, [int? noteIndex]) {
    if (state.isBusy || state.winnings > 0) return;
    final current = state.selectedBets[type] ?? 0;
    // Límite máximo por símbolo
    if (current >= _maxBetPerSymbol) {
      soundService.play(SoundEffect.betLimit);
      return;
    }
    // Validar crédito disponible antes de aceptar la apuesta
    if (state.credits <= state.totalSelectedBet) {
      soundService.play(SoundEffect.betLimit);
      return;
    }
    final next = Map<String, int>.from(state.selectedBets);
    next[type] = current + 1;
    state = state.copyWith(selectedBets: next);
    
    // Si pasamos un índice, reproducimos esa nota de la escala de piano.
    if (noteIndex != null) {
      // Usamos el noteIndex para la escala pentatónica, y le pasamos un paneo
      // distribuido de izquierda a derecha (0 a 8) mapeado a (-1.0 a 1.0)
      final balance = (noteIndex - 4) / 4.0;
      soundService.playVintageTick(noteIndex, balance: balance);
    } else {
      soundService.playBetArpeggio();
    }
  }

  void clearBetsAndHighlights() {
    state = state.copyWith(
      selectedBets: const {},
    );
  }

  // ─────────────────────────── Messages ───────────────────────────

  void _showMessage(String? sym, String? title, [String? details]) {
    state = state.copyWith(
      messageSymbol: sym,
      messageTitle: title,
      messageDetails: details,
      showLogo: false,
    );
  }

  void _hideMessage() {
    state = state.copyWith(
      messageSymbol: null,
      messageTitle: null,
      messageDetails: null,
      showLogo: !state.doublingActive,
    );
  }

  // ─────────────────────────── Spin ───────────────────────────────

  Future<void> playOrDouble() async {
    if (state.isBusy) return;

    if (state.canDouble) {
      _startDoubleUp();
      return;
    }

    // If no new bets but lastBet exists, repeat it.
    if (state.totalSelectedBet == 0 && state.totalLastBet > 0) {
      if (state.credits >= state.totalLastBet) {
        state = state.copyWith(selectedBets: Map.from(state.lastBet));
      } else {
        return;
      }
    }
    if (state.totalSelectedBet == 0) return;
    if (state.credits < state.totalSelectedBet) return;

    await _spin(free: false);
  }

  Future<void> _spin({required bool free}) async {
    final cost = state.totalSelectedBet;
    if (!free) {
      state = state.copyWith(
        lastBet: Map.from(state.selectedBets),
        credits: state.credits - cost,
        lastWin: 0,
      );
      _persistCredits();
    }

    state = state.copyWith(
      phase: SpinPhase.spinning,
      winnerSlots: const {},
      eventWonSlots: const {},
    );
    _hideMessage();
    soundService.startSpinLoop();

    final totalSteps = _engine.randomTotalSteps();
    await _runLightLoop(
      totalSteps: totalSteps,
      onStep: (step) {
        final slotId = kLightPath[state.currentLightIndex];
        state = state.copyWith(activeSlotId: slotId);
        
        // Calculamos el balance estéreo basado en la columna (0 a 6)
        final pos = kSlotGridPos[slotId]!;
        final balance = (pos.col - 3) / 3.0; // Rango: -1.0 a 1.0

        // Usamos la escala pentatónica de DO con paneo estéreo
        soundService.playVintageTick(state.currentLightIndex, balance: balance);

        state = state.copyWith(
          currentLightIndex: (state.currentLightIndex + 1) % kLightPath.length,
        );
      },
    );
    soundService.stopSpinLoop();

    await _resolveSpin(free: free);
  }

  Future<void> _resolveSpin({required bool free}) async {
    final n = kLightPath.length;
    final finalPathIndex = (state.currentLightIndex - 1 + n) % n;
    final winningSlotId = kLightPath[finalPathIndex];
    final winningSymbol = state.symbolsOnBoard[winningSlotId];
    final betOnSymbol = state.selectedBets[winningSymbol.effectiveType] ?? 0;

    if (winningSymbol.prize > 0 && betOnSymbol > 0) {
      final prize = winningSymbol.prize * betOnSymbol;
      state = state.copyWith(
        winnings: state.winnings + prize,
        lastWin: prize,
        winnerSlots: {winningSlotId},
      );
      _showMessage(winningSymbol.display, '¡GANASTE!', '+$prize');
      soundService.play(
          winningSymbol.prize >= 40 ? SoundEffect.bigWin : SoundEffect.win);

      _statsDao.recordSpin(SpinRecord(
        totalBet: free ? 0 : state.totalSelectedBet,
        prize: prize,
        wasEvent: false,
      ));

      if (free) {
        await Future.delayed(const Duration(milliseconds: 1500));
        await _endSpecialEvent('TIRO GRATIS TERMINADO', state.lastWin);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 2500));
      _afterSpinFinalize();
      return;
    }

    if (winningSymbol.isOnceMore && state.phase != SpinPhase.event) {
      await _triggerSpecialEvent();
      return;
    }

    _showMessage(winningSymbol.display, 'NO HUBO SUERTE');
    soundService.play(SoundEffect.lose);
    _statsDao.recordSpin(SpinRecord(
      totalBet: free ? 0 : state.totalSelectedBet,
      prize: 0,
      wasEvent: false,
    ));
    if (free) {
      await Future.delayed(const Duration(milliseconds: 1500));
      await _endSpecialEvent('TIRO GRATIS TERMINADO', 0);
      return;
    }
    await Future.delayed(const Duration(milliseconds: 2500));
    _afterSpinFinalize();
  }

  void _afterSpinFinalize() {
    state = state.copyWith(
      phase: SpinPhase.idle,
      activeSlotId: null,
      winnerSlots: const {},
      // Keep selectedBets even after a win or loss as requested.
      selectedBets: state.selectedBets,
    );
    _hideMessage();
  }

  // ──────────────────────── Special Events ────────────────────────

  Future<void> _triggerSpecialEvent() async {
    if (state.totalSelectedBet == 0) {
      _showMessage('🤔', '¡HAZ UNA APUESTA!', 'PARA JUGAR EL EVENTO');
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(phase: SpinPhase.idle, activeSlotId: null);
      _hideMessage();
      return;
    }

    final deactivated = <int>{};
    for (var i = 0; i < state.symbolsOnBoard.length; i++) {
      if (state.symbolsOnBoard[i].isOnceMore) deactivated.add(i);
    }

    state = state.copyWith(
      phase: SpinPhase.event,
      deactivatedSlots: deactivated,
      winnerSlots: const {},
      eventWonSlots: const {},
    );
    soundService.play(SoundEffect.special);

    final chosen = _engine.pickSpecialEvent();
    switch (chosen) {
      case 'snake':
        await _snakeEvent();
        break;
      case 'three_prizes':
        await _threePrizesEvent();
        break;
      case 'free_spin':
        await _freeSpinEvent();
        break;
    }
  }

  Future<void> _snakeEvent() async {
    _showMessage('🐍', '¡CULEBRITA!', '¡AHÍ VIENE!');
    await Future.delayed(const Duration(seconds: 2));

    final totalSteps = _engine.randomSnakeSteps();
    final n = kLightPath.length;

    soundService.startSpinLoop();
    await _runLightLoop(
      totalSteps: totalSteps,
      initialSpeed: 50,
      slowdownAdditive: true,
      onStep: (step) {
        final head = state.currentLightIndex;
        final parts = {
          kLightPath[head],
          kLightPath[(head - 1 + n) % n],
          kLightPath[(head - 2 + n) % n],
        };
        state = state.copyWith(
          activeSlotId: kLightPath[head],
          activeSnakeSlots: parts,
        );

        // Calculamos el balance estéreo basado en la columna (0 a 6)
        final pos = kSlotGridPos[kLightPath[head]]!;
        final balance = (pos.col - 3) / 3.0; // Rango: -1.0 a 1.0
        
        soundService.playVintageTick(state.currentLightIndex, balance: balance);

        state = state.copyWith(
          currentLightIndex: (state.currentLightIndex + 1) % n,
        );
      },
    );
    soundService.stopSpinLoop();

    final finalHeadIndex = (state.currentLightIndex - 1 + n) % n;
    final partsIndices = _engine.snakePartsFromHead(finalHeadIndex);

    int totalSnakePrize = 0;
    final winners = <int>{};
    for (final partIndex in partsIndices) {
      final slotId = kLightPath[partIndex];
      final symbol = state.symbolsOnBoard[slotId];
      winners.add(slotId);
      final bet = state.selectedBets[symbol.effectiveType] ?? 0;
      if (!symbol.isOnceMore && bet > 0) {
        totalSnakePrize += symbol.prize * bet;
      }
    }

    if (totalSnakePrize > 0) soundService.play(SoundEffect.bigWin);
    state = state.copyWith(
      winnerSlots: winners,
      eventWonSlots: winners,
      activeSnakeSlots: const {},
      winnings: state.winnings + totalSnakePrize,
    );

    _statsDao.recordSpin(SpinRecord(
      totalBet: state.totalSelectedBet,
      prize: totalSnakePrize,
      wasEvent: true,
      eventType: 'snake',
    ));

    await _endSpecialEvent('CULEBRITA TERMINADA', totalSnakePrize);
  }

  Future<void> _threePrizesEvent() async {
    _showMessage('🌟', '¡RULETA LOCA!', '3 PREMIOS AL AZAR');
    await Future.delayed(const Duration(seconds: 2));

    final targets = _engine.pickThreePrizeTargets(
      board: state.symbolsOnBoard,
      selectedBets: state.selectedBets,
    );

    if (targets.isEmpty) {
      await _endSpecialEvent('SIN PREMIOS APOSTADOS', 0);
      _statsDao.recordSpin(SpinRecord(
        totalBet: state.totalSelectedBet,
        prize: 0,
        wasEvent: true,
        eventType: 'three_prizes',
      ));
      return;
    }

    int totalEventWinnings = 0;
    final winners = <int>{};

    for (final targetSlotId in targets) {
      final targetLightIndex = kLightPath.indexOf(targetSlotId);
      final stepsTotal =
          _engine.stepsToTarget(state.currentLightIndex, targetLightIndex);

      await _runLightLoop(
        totalSteps: stepsTotal,
        onStep: (step) {
          state = state.copyWith(
              activeSlotId: kLightPath[state.currentLightIndex]);

          // Pasamos el índice entero para la escala pentatónica
          soundService.playVintageTick(state.currentLightIndex);

          state = state.copyWith(
            currentLightIndex:
                (state.currentLightIndex + 1) % kLightPath.length,
          );
        },
      );

      final symbol = state.symbolsOnBoard[targetSlotId];
      final bet = state.selectedBets[symbol.effectiveType] ?? 0;
      final prize = symbol.prize * bet;
      totalEventWinnings += prize;
      winners.add(targetSlotId);

      state = state.copyWith(
        winnings: state.winnings + prize,
        winnerSlots: {targetSlotId},
        eventWonSlots: winners,
      );
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    _statsDao.recordSpin(SpinRecord(
      totalBet: state.totalSelectedBet,
      prize: totalEventWinnings,
      wasEvent: true,
      eventType: 'three_prizes',
    ));

    await _endSpecialEvent('RULETA TERMINADA', totalEventWinnings);
  }

  Future<void> _freeSpinEvent() async {
    _showMessage('🔄', '¡TIRO GRATIS!', null);
    await Future.delayed(const Duration(seconds: 2));
    await _spin(free: true);
  }

  Future<void> _endSpecialEvent(String message, int eventWinnings) async {
    _showMessage('💰', message, '+$eventWinnings');
    await Future.delayed(const Duration(milliseconds: 2500));

    state = state.copyWith(
      phase: SpinPhase.idle,
      activeSlotId: null,
      activeSnakeSlots: const {},
      winnerSlots: const {},
      eventWonSlots: const {},
      deactivatedSlots: const {},
      lastWin: eventWinnings,
      lastBet: const {},
      // Keep selectedBets as requested.
      selectedBets: state.selectedBets,
    );
    _hideMessage();
  }

  // ─────────────────────── Light loop helper ──────────────────────

  Future<void> _runLightLoop({
    required int totalSteps,
    required void Function(int step) onStep,
    int initialSpeed = 120,
    bool slowdownAdditive = false,
  }) {
    final completer = Completer<void>();
    var step = 0;

    void schedule() {
      final delay = slowdownAdditive
          ? _snakeDelay(step: step, totalSteps: totalSteps,
              baseSpeed: initialSpeed)
          : SpinEngine.stepDelayMs(
              currentStep: step,
              totalSteps: totalSteps,
              initialSpeed: initialSpeed,
            );

      _stepTimer = Timer(Duration(milliseconds: delay), () {
        onStep(step);
        step++;
        if (step < totalSteps) {
          schedule();
        } else {
          completer.complete();
        }
      });
    }

    schedule();
    return completer.future;
  }

  int _snakeDelay({
    required int step,
    required int totalSteps,
    required int baseSpeed,
  }) {
    var speed = baseSpeed;
    if (step > totalSteps - 15) speed += 15 * (step - (totalSteps - 15));
    return speed.clamp(20, 600);
  }

  // ──────────────────────── Double Up ─────────────────────────────

  void _startDoubleUp() {
    state = state.copyWith(
      doublingActive: true,
      phase: SpinPhase.doubling,
      doubleHighlight: null,
      doubleWinner: null,
      doubleResult: DoubleResult.none,
      showLogo: false,
    );
  }

  Future<void> chooseDouble(String choice) async {
    if (!state.doublingActive) return;
    if (state.doubleResult != DoubleResult.none) return;
    if (state.doubleWinner != null) return; // animation in progress

    final steps = _engine.randomDoubleSteps();
    var current = DateTime.now().microsecondsSinceEpoch.isEven ? 'left' : 'right';
    var currentStep = 0;
    var speed = 50;

    final completer = Completer<void>();

    void run() {
      _stepTimer = Timer(Duration(milliseconds: speed), () {
        state = state.copyWith(doubleHighlight: current);
        current = current == 'left' ? 'right' : 'left';
        currentStep++;
        if (currentStep > steps - 5) speed += 30;
        if (currentStep < steps) {
          run();
        } else {
          completer.complete();
        }
      });
    }

    run();
    await completer.future;

    final winner = _engine.pickDoubleWinner();
    state = state.copyWith(
      doubleWinner: winner,
      doubleHighlight: winner,
      doubleResult: choice == winner ? DoubleResult.won : DoubleResult.lost,
    );

    if (choice == winner) {
      state = state.copyWith(winnings: state.winnings * 2);
      soundService.play(SoundEffect.doubleWin);
    } else {
      state = state.copyWith(winnings: 0);
      soundService.play(SoundEffect.doubleLose);
    }

    await Future.delayed(const Duration(seconds: 2));

    state = state.copyWith(
      doublingActive: false,
      phase: SpinPhase.idle,
      doubleHighlight: null,
      doubleWinner: null,
      doubleResult: DoubleResult.none,
      lastWin: 0,
      showLogo: true,
      selectedBets: const {},
      lastBet: const {},
    );
  }

  void cancelDoubleAndCashout() {
    if (!state.doublingActive) return;
    state = state.copyWith(
      doublingActive: false,
      phase: SpinPhase.idle,
      doubleHighlight: null,
      doubleWinner: null,
      doubleResult: DoubleResult.none,
      showLogo: true,
    );
    cashout();
  }

  // ───────────────────────── Cashout ──────────────────────────────

  void cashout() {
    if (state.winnings == 0 || state.isBusy) return;
    final newCredits = state.credits + state.winnings;
    soundService.play(SoundEffect.cashout);
    state = state.copyWith(
      credits: newCredits,
      winnings: 0,
      lastWin: 0,
      flashCredits: true,
      selectedBets: const {},
      lastBet: const {},
    );
    _persistCredits();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      state = state.copyWith(flashCredits: false);
    });
  }

  // ───────────────────────── Persistence ──────────────────────────

  Future<void> _persistCredits() async {
    await _creditsDao.write(state.credits);
  }

  Future<void> resetWallet({int credits = 100}) async {
    await _creditsDao.reset(credits: credits);
    await _statsDao.reset();
    state = GameState.initial(
      credits: credits,
      board: _engine.buildBoard(),
    );
  }

  void rebuildBoard() {
    state = state.copyWith(symbolsOnBoard: _engine.buildBoard());
  }
}
