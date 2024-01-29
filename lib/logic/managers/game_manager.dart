import 'package:chess/chess.dart' as chess;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:simple_chess_board/simple_chess_board.dart';

import 'package:chess_against_engine/logic/history_builder.dart';
import 'package:chess_against_engine/logic/utils.dart';

const emptyPosition = '4k3/8/8/8/8/8/8/4K3 w - - 0 1';

class GameState extends Equatable {
  final String positionFen;
  final bool whiteTurn;
  final bool gameOver;
  final PlayerType whitePlayerType;
  final PlayerType blackPlayerType;
  final bool cpuCanPlay;
  final String startPosition;
  final bool gameStart;
  final bool gameInProgress;
  final bool engineThinking;
  final double score;

  const GameState({
    required this.positionFen,
    required this.whiteTurn,
    required this.gameOver,
    required this.whitePlayerType,
    required this.blackPlayerType,
    required this.cpuCanPlay,
    required this.startPosition,
    required this.gameStart,
    required this.gameInProgress,
    required this.engineThinking,
    required this.score,
  });

  @override
  List<Object?> get props => [
        positionFen,
        whiteTurn,
        gameOver,
        whitePlayerType,
        blackPlayerType,
        cpuCanPlay,
        startPosition,
        gameStart,
        gameInProgress,
        engineThinking,
        score,
      ];

  GameState copyWith({
    String? positionFen,
    bool? whiteTurn,
    bool? gameOver,
    PlayerType? whitePlayerType,
    PlayerType? blackPlayerType,
    bool? cpuCanPlay,
    String? startPosition,
    bool? gameStart,
    bool? gameInProgress,
    bool? engineThinking,
    double? score,
  }) {
    return GameState(
      positionFen: positionFen ?? this.positionFen,
      whiteTurn: whiteTurn ?? this.whiteTurn,
      gameOver: gameOver ?? this.gameOver,
      whitePlayerType: whitePlayerType ?? this.whitePlayerType,
      blackPlayerType: blackPlayerType ?? this.blackPlayerType,
      cpuCanPlay: cpuCanPlay ?? this.cpuCanPlay,
      startPosition: startPosition ?? this.startPosition,
      gameStart: gameStart ?? this.gameStart,
      gameInProgress: gameInProgress ?? this.gameInProgress,
      engineThinking: engineThinking ?? this.engineThinking,
      score: score ?? this.score,
    );
  }
}

class GameManager extends ValueNotifier<GameState> {
  chess.Chess _gameLogic = chess.Chess();

  GameManager._sharedInstance()
      : super(
          const GameState(
              positionFen: emptyPosition,
              whiteTurn: true,
              gameOver: false,
              whitePlayerType: PlayerType.computer,
              blackPlayerType: PlayerType.computer,
              cpuCanPlay: false,
              startPosition: chess.Chess.DEFAULT_POSITION,
              gameStart: false,
              gameInProgress: false,
              engineThinking: false,
              score: 0.0),
        ) {
    _gameLogic.load(emptyPosition);
  }

  static final GameManager _shared = GameManager._sharedInstance();

  factory GameManager() => _shared;

  GameState get currentState => value;

  bool processComputerMove({
    required String from,
    required String to,
    required String? promotion,
  }) {
    final moveHasBeenMade = _gameLogic.move({
      'from': from,
      'to': to,
      'promotion': promotion,
    });
    value = value.copyWith(
      engineThinking: false,
      cpuCanPlay: false,
      gameOver: _gameLogic.game_over,
      whiteTurn: _gameLogic.turn == chess.Color.WHITE,
      positionFen: _gameLogic.fen,
    );
    notifyListeners();

    return moveHasBeenMade;
  }

  void clearGameStartFlag() {
    value = value.copyWith(gameStart: false);
    notifyListeners();
  }

  bool processPlayerMove({
    required String from,
    required String to,
    required String? promotion,
  }) {
    final moveHasBeenMade = _gameLogic.move({
      'from': from,
      'to': to,
      'promotion': promotion,
    });
    value = value.copyWith(
      gameOver: _gameLogic.game_over,
      whiteTurn: _gameLogic.turn == chess.Color.WHITE,
      positionFen: _gameLogic.fen,
    );
    notifyListeners();
    return moveHasBeenMade;
  }

  void startNewGame({
    String startPosition = chess.Chess.DEFAULT_POSITION,
    bool playerHasWhite = true,
  }) {
    _gameLogic.load(startPosition);
    value = value.copyWith(
      score: 0.0,
      startPosition: startPosition,
      whitePlayerType: playerHasWhite ? PlayerType.human : PlayerType.computer,
      blackPlayerType: playerHasWhite ? PlayerType.computer : PlayerType.human,
      gameStart: true,
      gameInProgress: true,
      positionFen: _gameLogic.fen,
      whiteTurn: _gameLogic.turn == chess.Color.WHITE,
      gameOver: _gameLogic.game_over,
    );
    notifyListeners();
  }

  void stopGame() {
    value = value.copyWith(
      whitePlayerType: PlayerType.computer,
      blackPlayerType: PlayerType.computer,
      gameInProgress: false,
      engineThinking: false,
    );
    notifyListeners();
  }

  void loadStartPosition() {
    _gameLogic = chess.Chess();
    _gameLogic.load(value.startPosition);
    value = value.copyWith(
      positionFen: _gameLogic.fen,
      whiteTurn: _gameLogic.turn == chess.Color.WHITE,
      gameOver: _gameLogic.game_over,
    );
    notifyListeners();
  }

  void loadPosition(String position) {
    _gameLogic = chess.Chess();
    _gameLogic.load(position);
    value = value.copyWith(
      positionFen: _gameLogic.fen,
      whiteTurn: _gameLogic.turn == chess.Color.WHITE,
      gameOver: _gameLogic.game_over,
    );
    notifyListeners();
  }

  void allowCpuThinking() {
    value = value.copyWith(
      engineThinking: true,
      cpuCanPlay: true,
    );
    notifyListeners();
  }

  void forbidCpuThinking() {
    value = value.copyWith(
      engineThinking: false,
      cpuCanPlay: false,
    );
    notifyListeners();
  }

  void updateScore(double score) {
    value = value.copyWith(score: score);
    notifyListeners();
  }

  String getLastMoveFan() {
    final lastPlayedMove = _gameLogic.history.last.move;

    // In order to get move SAN, it must not be done on board yet !
    // So we rollback the move, then we'll make it happen again.
    _gameLogic.undo_move();
    final san = _gameLogic.move_to_san(lastPlayedMove);
    _gameLogic.make_move(lastPlayedMove);

    // Move has been played: we need to revert player turn for the SAN.
    return san.toFan(whiteMove: !value.whiteTurn);
  }

  Move getLastMove() {
    final lastPlayedMove = _gameLogic.history.last.move;
    final relatedMoveFromSquareIndex = CellIndexConverter(lastPlayedMove.from)
        .convertSquareIndexFromChessLib();
    final relatedMoveToSquareIndex =
        CellIndexConverter(lastPlayedMove.to).convertSquareIndexFromChessLib();
    return Move(
      from: Cell.fromSquareIndex(relatedMoveFromSquareIndex),
      to: Cell.fromSquareIndex(relatedMoveToSquareIndex),
    );
  }

  String getResultString() {
    if (_gameLogic.in_checkmate) {
      return _gameLogic.turn == chess.Color.WHITE ? '0-1' : '1-0';
    }
    if (_gameLogic.in_draw) {
      return '1/2-1/2';
    }
    return '*';
  }

  Widget getGameEndedType() {
    dynamic result;
    if (_gameLogic.in_checkmate) {
      result = (_gameLogic.turn == chess.Color.WHITE)
          ? I18nText('game_termination.black_checkmate_white')
          : I18nText('game_termination.white_checkmate_black');
    } else if (_gameLogic.in_stalemate) {
      result = I18nText('game_termination.stalemate');
    } else if (_gameLogic.in_threefold_repetition) {
      result = I18nText('game_termination.repetitions');
    } else if (_gameLogic.insufficient_material) {
      result = I18nText('game_termination.insufficient_material');
    } else if (_gameLogic.in_draw) {
      result = I18nText('game_termination.fifty_moves');
    }
    return result;
  }
}
