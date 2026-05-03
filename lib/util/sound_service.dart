import 'package:audioplayers/audioplayers.dart';

/// Identifiers for every sound effect in the game.
enum SoundEffect {
  bet,        // Click al apostar
  betLimit,   // Error: límite de apuesta o sin crédito
  win,        // Premio normal
  bigWin,     // Premio grande
  lose,       // Sin suerte
  doubleWin,  // Dobló y ganó
  doubleLose, // Dobló y perdió
  cashout,    // Cobrar ganancias
  special,    // Evento especial disparado
}

/// Maps every [SoundEffect] to its asset path inside the assets/ folder.
const Map<SoundEffect, String> _kAssets = {
  SoundEffect.bet:        'sounds/bet.wav',
  SoundEffect.betLimit:   'sounds/bet_limit.wav',
  SoundEffect.win:        'sounds/win.wav',
  SoundEffect.bigWin:     'sounds/big_win.wav',
  SoundEffect.lose:       'sounds/lose.wav',
  SoundEffect.doubleWin:  'sounds/double_win.wav',
  SoundEffect.doubleLose: 'sounds/double_lose.wav',
  SoundEffect.cashout:    'sounds/cashout.wav',
  SoundEffect.special:    'sounds/special.wav',
};

class SoundService {
  bool muted = false;

  /// One AudioPlayer per one-shot effect.
  final Map<SoundEffect, AudioPlayer> _players = {};

  /// Dedicated players for each pentatonic note (0-9).
  final Map<int, AudioPlayer> _pentatonicPlayers = {};

  /// Dedicated player for the vintage bet arpeggio.
  AudioPlayer? _betArpeggioPlayer;

  // ── init ────────────────────────────────────────────────

  Future<void> init() async {
    // Configurar AudioContext para evitar que los sonidos se choquen (ducking)
    // o bajen el volumen de la aplicación.
    final audioContext = AudioContextConfig(
      route: AudioContextConfigRoute.system,
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: false,
    ).build();
    await AudioPlayer.global.setAudioContext(audioContext);

    // 1. Pentatonic notes (Pre-loaded for low latency)
    for (var i = 0; i < 10; i++) {
      final p = AudioPlayer();
      await p.setSource(AssetSource('sounds/pentatonic_$i.wav'));
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1.0); // Subimos el volumen para que se escuche claro
      _pentatonicPlayers[i] = p;
    }

    // 2. Vintage Bet Arpeggio
    _betArpeggioPlayer = AudioPlayer();
    await _betArpeggioPlayer!.setSource(AssetSource('sounds/vintage_bet.wav'));
    await _betArpeggioPlayer!.setReleaseMode(ReleaseMode.stop);
    await _betArpeggioPlayer!.setVolume(1.0); // Subimos el volumen

    // 3. One-shot players
    for (final effect in SoundEffect.values) {
      final p = AudioPlayer();
      await p.setSource(AssetSource(_kAssets[effect]!));
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1.0);
      _players[effect] = p;
    }
  }

  // ── spin loop ───────────────────────────────────────────

  int _lastTickTimeMs = 0;
  int _lastPlayedNote = -1;

  /// Plays a "Vintage Chirp" using pre-loaded pentatonic scale files.
  void playVintageTick(num noteIndex, {double balance = 0.0}) {
    if (muted) return;
    
    // THROTTLE: Límite de 20ms para evitar atascos.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTickTimeMs < 20) return;
    _lastTickTimeMs = now;

    try {
      final fileIndex = noteIndex.toInt() % 10;
      final player = _pentatonicPlayers[fileIndex];
      player?.setBalance(balance);
      
      // Disparo limpio sin cortar abruptamente la onda anterior (evita "pops")
      player?.seek(Duration.zero).then((_) => player.resume());
    } catch (_) {}
  }

  /// Plays the pre-baked descending arpeggio for bet buttons.
  void playBetArpeggio() {
    if (muted) return;
    try {
      _betArpeggioPlayer?.seek(Duration.zero).then((_) => _betArpeggioPlayer?.resume());
    } catch (_) {}
  }

  /// Call when the reel starts spinning.
  void startSpinLoop() {
    // El audio de fondo original fue removido.
    // Ahora dependemos de los ticks generados en el bucle principal.
  }

  /// Call when the reel stops.
  void stopSpinLoop() {
    // No hacer nada, dejamos que la última nota decaiga naturalmente
  }

  // ── one-shot effects ─────────────────────────────────────

  void play(SoundEffect effect) {
    if (muted) return;
    final player = _players[effect];
    final path   = _kAssets[effect];
    if (player == null || path == null) return;
    try {
      player.play(AssetSource(path));
    } catch (_) {}
  }

  // ── dispose ─────────────────────────────────────────────

  void dispose() {
    for (final p in _pentatonicPlayers.values) { p.dispose(); }
    _betArpeggioPlayer?.dispose();
    for (final p in _players.values) { p.dispose(); }
    _players.clear();
  }
}

/// Global singleton – initialised once in main.dart.
final soundService = SoundService();
