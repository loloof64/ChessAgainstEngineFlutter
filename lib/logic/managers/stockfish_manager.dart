import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine_state.dart';

class SkillLevel extends Equatable {
  final int defaultLevel;
  final int currentLevel;
  final int minLevel;
  final int maxLevel;

  const SkillLevel({
    required this.defaultLevel,
    required this.currentLevel,
    required this.minLevel,
    required this.maxLevel,
  });

  @override
  List<Object?> get props => [defaultLevel, currentLevel, minLevel, maxLevel];

  SkillLevel copyWith({
    int? defaultLevel,
    int? currentLevel,
    int? minLevel,
    int? maxLevel,
  }) {
    return SkillLevel(
      defaultLevel: defaultLevel ?? this.defaultLevel,
      currentLevel: currentLevel ?? this.currentLevel,
      minLevel: minLevel ?? this.minLevel,
      maxLevel: maxLevel ?? this.maxLevel,
    );
  }

  @override
  String toString() {
    return 'SkillLevel(defaultLevel: $defaultLevel, currentLevel: $currentLevel, minLevel: $minLevel, maxLevel: $maxLevel)';
  }
}

class StockfishManagerState extends Equatable {
  final SkillLevel? skillLevel;
  final StockfishState engineState;

  const StockfishManagerState({
    this.skillLevel,
    required this.engineState,
  });

  @override
  List<Object?> get props => [skillLevel, engineState];

  StockfishManagerState copyWith({
    SkillLevel? skillLevel,
    StockfishState? engineState,
  }) {
    return StockfishManagerState(
      skillLevel: skillLevel ?? this.skillLevel,
      engineState: engineState ?? this.engineState,
    );
  }

  StockfishManagerState withClearedSkillLevel() {
    return StockfishManagerState(
      skillLevel: null,
      engineState: engineState,
    );
  }
}

typedef SetSkillLevelOptionCallback = void Function({
  required int defaultLevel,
  required int minLevel,
  required int maxLevel,
});
typedef UnsetSkillLevelOptionCallback = void Function();
typedef HandleReadyOkCallback = void Function();
typedef HandleScoreCpCallback = void Function({required double scoreCp});
typedef BestMoveCallback = void Function({
  required String from,
  required String to,
  required String? promotion,
});

class StockfishManager extends ValueNotifier<StockfishManagerState> {
  final List<SetSkillLevelOptionCallback> _setSkillLevelOptionCallbacks = [];
  final List<UnsetSkillLevelOptionCallback> _unsetSkillLevelOptionCallbacks =
      [];
  final List<HandleReadyOkCallback> _handleReadyOkCallbacks = [];
  final List<HandleScoreCpCallback> _handleScoreCpCallbacks = [];
  final List<BestMoveCallback> _bestMoveCallbacks = [];

  StockfishManager._sharedInstance()
      : super(const StockfishManagerState(
          skillLevel: null,
          engineState: StockfishState.starting,
        ));
  static final StockfishManager _shared = StockfishManager._sharedInstance();

  factory StockfishManager() => _shared;

  void addSetSkillLevelOptionCallback(SetSkillLevelOptionCallback callback) {
    _setSkillLevelOptionCallbacks.add(callback);
  }

  void addUnsetSkillLevelOptionCallback(
      UnsetSkillLevelOptionCallback callback) {
    _unsetSkillLevelOptionCallbacks.add(callback);
  }

  void addHandleReadyOkCallback(HandleReadyOkCallback callback) {
    _handleReadyOkCallbacks.add(callback);
  }

  void addHandleScoreCpCallback(HandleScoreCpCallback callback) {
    _handleScoreCpCallbacks.add(callback);
  }

  void addBestMoveCallback(BestMoveCallback callback) {
    _bestMoveCallbacks.add(callback);
  }

  void removeSetSkillLevelOptionCallback(SetSkillLevelOptionCallback callback) {
    _setSkillLevelOptionCallbacks.remove(callback);
  }

  void removeUnsetSkillLevelOptionCallback(
      UnsetSkillLevelOptionCallback callback) {
    _unsetSkillLevelOptionCallbacks.remove(callback);
  }

  void removeHandleReadyOkCallback(HandleReadyOkCallback callback) {
    _handleReadyOkCallbacks.remove(callback);
  }

  void removeHandleScoreCpCallback(HandleScoreCpCallback callback) {
    _handleScoreCpCallbacks.remove(callback);
  }

  void removeBestMoveCallback(BestMoveCallback callback) {
    _bestMoveCallbacks.remove(callback);
  }

  late Stockfish _stockfish;
  late StreamSubscription<String> _stockfishOutputSubsciption;

  SkillLevel? get skillLevel => value.skillLevel;
  StockfishState get state => value.engineState;

  void setSkillLevel({
    required int level,
  }) {
    _stockfish.stdin = 'setoption name Skill Level value $level';
    SkillLevel? newSkillLevel = value.skillLevel?.copyWith(currentLevel: level);
    value = value.copyWith(skillLevel: newSkillLevel);
  }

  void start() async {
    try {
      if (_stockfish.state.value == StockfishState.ready ||
          _stockfish.state.value == StockfishState.starting) {
        return;
      }
      // ignore: empty_catches
    } catch (ex) {}
    try {
      _stockfishOutputSubsciption.cancel();
      // ignore: empty_catches
    } catch (ex) {}
    _stockfish = Stockfish();
    _stockfishOutputSubsciption = _stockfish.stdout.listen((message) {
      _processEngineStdOut(message);
    });
    await Future.delayed(const Duration(milliseconds: 800));
    _stockfish.stdin = 'uci';
    await Future.delayed(const Duration(milliseconds: 200));
    _stockfish.stdin = 'isready';
    await Future.delayed(const Duration(milliseconds: 50));
  }

  void stop() async {
    if (_stockfish.state.value == StockfishState.disposed ||
        _stockfish.state.value == StockfishState.error) {
      return;
    }
    _stockfishOutputSubsciption.cancel();
    _stockfish.stdin = 'quit';
    await Future.delayed(const Duration(milliseconds: 200));
    _stockfishOutputSubsciption.cancel();
  }

  void _processEngineStdOut(String message) {
    if (message.contains("option")) {
      final skillLevelPart = RegExp(
              r'option name Skill Level type spin default (\d+) min (\d+) max (\d+)')
          .firstMatch(message);
      if (skillLevelPart != null) {
        final defaultLevel = int.parse(skillLevelPart.group(1)!);
        final minLevel = int.parse(skillLevelPart.group(2)!);
        final maxLevel = int.parse(skillLevelPart.group(3)!);

        for (SetSkillLevelOptionCallback callback
            in _setSkillLevelOptionCallbacks) {
          callback(
            defaultLevel: defaultLevel,
            minLevel: minLevel,
            maxLevel: maxLevel,
          );
        }

        value = value.copyWith(
          skillLevel: SkillLevel(
            defaultLevel: defaultLevel,
            currentLevel: defaultLevel,
            minLevel: minLevel,
            maxLevel: maxLevel,
          ),
        );
      } else {
        for (UnsetSkillLevelOptionCallback callback
            in _unsetSkillLevelOptionCallbacks) {
          callback();
        }
      }
    }
    if (message.contains("uciok")) {
      _stockfish.stdin = 'isready';
      return;
    }
    if (message.contains("readyok")) {
      for (HandleReadyOkCallback callback in _handleReadyOkCallbacks) {
        callback();
      }
      return;
    }
    if (message.contains("score cp")) {
      final scores = RegExp(r"score cp ([0-9-]+)")
          .allMatches(message)
          .map((e) => e.group(1))
          .map((e) => int.parse(e!) / 100.0);
      for (var score in scores) {
        for (HandleScoreCpCallback callback in _handleScoreCpCallbacks) {
          callback(scoreCp: score);
        }
      }
    }
    if (message.contains("bestmove")) {
      _processEngineBestMoveMessage(message);
    }
  }

  void _processEngineBestMoveMessage(String message) {
    final bestMoveIndex = message.indexOf("bestmove");
    final bestMoveMessage = message.substring(bestMoveIndex);
    final parts = bestMoveMessage.split(" ");
    final moveAlgebraic = parts[1];
    final from = moveAlgebraic.substring(0, 2);
    final to = moveAlgebraic.substring(2, 4);
    final promotion =
        moveAlgebraic.length > 4 ? moveAlgebraic.substring(4, 5) : null;
    for (BestMoveCallback callback in _bestMoveCallbacks) {
      callback(
        from: from,
        to: to,
        promotion: promotion,
      );
    }
  }

  Future<void> startEvaluation(
      {required String positionFen, double thinkingTimeMs = 1000.0}) async {
    await Future.delayed(const Duration(seconds: 1));
    _stockfish.stdin = "position fen $positionFen";
    _stockfish.stdin = "go movetime $thinkingTimeMs";
  }
}
