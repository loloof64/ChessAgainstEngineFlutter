import 'dart:async';

import 'package:stockfish_chess_engine/stockfish.dart';
import 'package:stockfish_chess_engine/stockfish_state.dart';

class SkillLevel {
  int defaultLevel;
  int currentLevel;
  int minLevel;
  int maxLevel;

  SkillLevel(
      {required this.defaultLevel,
      required this.currentLevel,
      required this.minLevel,
      required this.maxLevel});
}

class StockfishManager {
  final void Function({
    required int defaultLevel,
    required int minLevel,
    required int maxLevel,
  }) setSkillLevelOption;
  final void Function() unsetSkillLevelOption;
  final void Function() handleReadyOk;
  final void Function({required double scoreCp}) handleScoreCp;
  final void Function(
      {required String from,
      required String to,
      required String? promotion}) onBestMove;

  StockfishManager({
    required this.setSkillLevelOption,
    required this.unsetSkillLevelOption,
    required this.handleReadyOk,
    required this.handleScoreCp,
    required this.onBestMove,
  });

  late Stockfish _stockfish;
  late StreamSubscription<String> _stockfishOutputSubsciption;
  SkillLevel? skillLevel;

  StockfishState get state => _stockfish.state.value;

  void setSkillLevel({
    required int level,
  }) {
    _stockfish.stdin = 'setoption name Skill Level value $level';
    skillLevel?.currentLevel = level;
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

        setSkillLevelOption(
          defaultLevel: defaultLevel,
          minLevel: minLevel,
          maxLevel: maxLevel,
        );
        skillLevel = SkillLevel(
          defaultLevel: defaultLevel,
          currentLevel: defaultLevel,
          minLevel: minLevel,
          maxLevel: maxLevel,
        );
      } else {
        unsetSkillLevelOption();
      }
    }
    if (message.contains("uciok")) {
      _stockfish.stdin = 'isready';
      return;
    }
    if (message.contains("readyok")) {
      handleReadyOk();
      return;
    }
    if (message.contains("score cp")) {
      final scores = RegExp(r"score cp ([0-9-]+)")
          .allMatches(message)
          .map((e) => e.group(1))
          .map((e) => int.parse(e!) / 100.0);
      for (var score in scores) {
        handleScoreCp(scoreCp: score);
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
    onBestMove(
      from: from,
      to: to,
      promotion: promotion,
    );
  }

  Future<void> startEvaluation(
      {required String positionFen, double thinkingTimeMs = 1000.0}) async {
    await Future.delayed(const Duration(seconds: 1));
    _stockfish.stdin = "position fen $positionFen";
    _stockfish.stdin = "go movetime $thinkingTimeMs";
  }
}
