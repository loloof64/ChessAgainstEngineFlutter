import 'package:chess/chess.dart' as chess;
import 'package:chess_against_engine/logic/history_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import '../utils.dart';

const emptyPosition = '8/8/8/8/8/8/8/8 w - - 0 1';

class GameManager {
  chess.Chess _gameLogic = chess.Chess();
  PlayerType _whitePlayerType = PlayerType.computer;
  PlayerType _blackPlayerType = PlayerType.computer;
  bool _cpuCanPlay = false;
  String _startPosition = chess.Chess.DEFAULT_POSITION;
  bool _gameStart = false;
  bool _gameInProgress = false;
  bool _engineThinking = false;
  double _score = 0.0;

  GameManager() {
    _gameLogic.load(emptyPosition);
  }

  bool get isGameOver => _gameLogic.game_over;
  bool get isGameStart => _gameStart;
  String get position => _gameLogic.fen;
  bool get whiteTurn => _gameLogic.turn == chess.Color.WHITE;
  String get startPosition => _startPosition;
  bool get cpuCanPlay => _cpuCanPlay;
  bool get gameInProgress => _gameInProgress;
  PlayerType get whitePlayerType => _whitePlayerType;
  PlayerType get blackPlayerType => _blackPlayerType;
  bool get engineThiking => _engineThinking;
  double get score => _score;

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
    _engineThinking = false;
    _cpuCanPlay = false;

    return moveHasBeenMade;
  }

  void clearGameStartFlag() {
    _gameStart = false;
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
    return moveHasBeenMade;
  }

  void startNewGame({
    String startPosition = chess.Chess.DEFAULT_POSITION,
    bool playerHasWhite = true,
  }) {
    _score = 0.0;
    _startPosition = startPosition;
    _whitePlayerType = playerHasWhite ? PlayerType.human : PlayerType.computer;
    _blackPlayerType = playerHasWhite ? PlayerType.computer : PlayerType.human;
    _gameStart = true;
    _gameInProgress = true;
    _gameLogic = chess.Chess();
    _gameLogic.load(_startPosition);
  }

  void stopGame() {
    _whitePlayerType = PlayerType.computer;
    _blackPlayerType = PlayerType.computer;
    _gameInProgress = false;
    _engineThinking = false;
  }

  void loadStartPosition() {
    _gameLogic = chess.Chess();
    _gameLogic.load(_startPosition);
  }

  void loadPosition(String position) {
    _gameLogic = chess.Chess();
    _gameLogic.load(position);
  }

  void allowCpuThinking() {
    _engineThinking = true;
    _cpuCanPlay = true;
  }

  void forbidCpuThinking() {
    _engineThinking = false;
    _cpuCanPlay = false;
  }

  void updateScore(double score) {
    _score = score;
  }

  String getLastMoveFan() {
    final lastPlayedMove = _gameLogic.history.last.move;

    // In order to get move SAN, it must not be done on board yet !
    // So we rollback the move, then we'll make it happen again.
    _gameLogic.undo_move();
    final san = _gameLogic.move_to_san(lastPlayedMove);
    _gameLogic.make_move(lastPlayedMove);

    // Move has been played: we need to revert player turn for the SAN.
    return san.toFan(whiteMove: !whiteTurn);
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
