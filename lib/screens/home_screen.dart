import 'dart:async';

import 'package:chess_against_engine/logic/managers/history_manager.dart';
import 'package:chess_against_engine/logic/managers/stockfish_manager.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_chess_board/models/board_arrow.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:stockfish_chess_engine/stockfish_state.dart';
import 'package:window_manager/window_manager.dart';

import '../components/dialog_buttons.dart';
import '../logic/history_builder.dart' hide File;
import '../logic/utils.dart';
import '../screens/home_screen_widgets.dart';
import '../screens/new_game_screen.dart';

const emptyPosition = '8/8/8/8/8/8/8/8 w - - 0 1';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  chess.Chess _gameLogic = chess.Chess();
  BoardColor _orientation = BoardColor.white;
  PlayerType _whitePlayerType = PlayerType.computer;
  PlayerType _blackPlayerType = PlayerType.computer;
  bool _cpuCanPlay = false;
  String _startPosition = chess.Chess.DEFAULT_POSITION;
  bool _gameStart = false;
  bool _gameInProgress = false;
  bool _skillLevelEditable = false;
  int _skillLevel = -1;
  int _skillLevelMin = -1;
  int _skillLevelMax = -1;
  bool _engineThinking = false;
  bool _scoreVisible = false;
  double _score = 0.0;

  final ScrollController _historyScrollController =
      ScrollController(initialScrollOffset: 0.0, keepScrollOffset: true);
  BoardArrow? _lastMoveArrow;
  late SharedPreferences _prefs;

  late StockfishManager _stockfishManager;
  late HistoryManager _historyManager;

  @override
  void initState() {
    windowManager.addListener(this);
    _overrideDefaultCloseHandler();
    _stockfishManager = StockfishManager(
      setSkillLevelOption: _setSkillLevelOption,
      unsetSkillLevelOption: _unsetSkillLevelOption,
      handleReadyOk: _makeComputerMove,
      handleScoreCp: _handleScoreCp,
      onBestMove: _processBestMove,
    );
    _historyManager = HistoryManager(
      onUpdateChildrenWidgets: _updateHistoryChildrenWidgets,
      onPositionSelected: _selectPosition,
      onSelectStartPosition: _selectStartPosition,
      isStartMoveNumber: _isStartMoveNumber,
    );
    _doStartStockfish();
    _gameLogic.load(emptyPosition);
    _initPreferences();
    super.initState();
  }

  bool _isStartMoveNumber(int moveNumber) {
    return int.parse(_startPosition.split(' ')[5]) == moveNumber;
  }

  void _setSkillLevelOption({
    required int defaultLevel,
    required int minLevel,
    required int maxLevel,
  }) {
    setState(() {
      _skillLevelMin = minLevel;
      _skillLevelMax = maxLevel;
      _skillLevel = defaultLevel;
      _skillLevelEditable = true;
    });
  }

  void _unsetSkillLevelOption() {
    setState(() {
      _skillLevelEditable = false;
    });
  }

  void _doStartStockfish() async {
    setState(() {
      _stockfishManager.start();
    });
  }

  void _stopStockfish() async {
    setState(() {
      _stockfishManager.stop();
    });
  }

  @override
  void dispose() {
    _stopStockfish();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    _stopStockfish();
    await Future.delayed(const Duration(milliseconds: 200));
    await windowManager.destroy();
  }

  void _processBestMove({
    required String from,
    required String to,
    required String? promotion,
  }) {
    if (!_cpuCanPlay) return;
    if (!_gameInProgress) return;
    final moveHasBeenMade =
        _gameLogic.move({'from': from, 'to': to, 'promotion': promotion});

    if (!moveHasBeenMade) return;

    setState(() {
      _lastMoveArrow = BoardArrow(from: from, to: to, color: Colors.blueAccent);
      _addMoveToHistory();
      _gameStart = false;
      _engineThinking = false;
      _cpuCanPlay = false;
    });

    if (_gameLogic.game_over) {
      final gameResultString = _getGameResultString();

      setState(() {
        _historyManager.addResultString(gameResultString);
        _whitePlayerType = PlayerType.computer;
        _blackPlayerType = PlayerType.computer;
        _gameInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _getGameEndedType(),
            ],
          ),
        ),
      );
    }

    setState(() {
      _historyManager.updateChildrenWidgets();
    });
    _makeComputerMove();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _makeComputerMove() {
    if (!_gameInProgress) return;
    final whiteTurn = _gameLogic.turn == chess.Color.WHITE;
    final computerTurn =
        (whiteTurn && _whitePlayerType == PlayerType.computer) ||
            (!whiteTurn && _blackPlayerType == PlayerType.computer);
    if (!computerTurn) return;

    setState(() {
      _engineThinking = true;
      _cpuCanPlay = true;
      _stockfishManager.startEvaluation(
        positionFen: _gameLogic.fen,
        thinkingTimeMs: _prefs.getDouble('engineThinkingTime') ?? 1000.0,
      );
    });
  }

  void _handleScoreCp({required double scoreCp}) {
    final cpuHasBlack = _whitePlayerType == PlayerType.human &&
        _blackPlayerType == PlayerType.computer;
    final cpuTurnAsBlack = cpuHasBlack && _cpuCanPlay;
    var realScore = scoreCp;
    if (cpuTurnAsBlack) {
      realScore *= -1;
    }
    setState(() {
      _score = realScore;
    });
  }

  /*
    Must be called after a move has just been
    added to _gameLogic
    Do not update state itself.
  */
  void _addMoveToHistory() {
    if (_historyManager.currentNode != null) {
      final whiteMove = _gameLogic.turn == chess.Color.WHITE;
      final lastPlayedMove = _gameLogic.history.last.move;

      // In order to get move SAN, it must not be done on board yet !
      // So we rollback the move, then we'll make it happen again.
      _gameLogic.undo_move();
      final san = _gameLogic.move_to_san(lastPlayedMove);
      _gameLogic.make_move(lastPlayedMove);

      // Move has been played: we need to revert player turn for the SAN.
      final fan = san.toFan(whiteMove: !whiteMove);
      final relatedMoveFromSquareIndex = CellIndexConverter(lastPlayedMove.from)
          .convertSquareIndexFromChessLib();
      final relatedMoveToSquareIndex = CellIndexConverter(lastPlayedMove.to)
          .convertSquareIndexFromChessLib();
      final relatedMove = Move(
        from: Cell.fromSquareIndex(relatedMoveFromSquareIndex),
        to: Cell.fromSquareIndex(relatedMoveToSquareIndex),
      );

      setState(() {
        _lastMoveArrow = BoardArrow(
            from: relatedMove.from.toString(),
            to: relatedMove.to.toString(),
            color: Colors.blueAccent);
        _historyManager.addMove(
          isWhiteTurnNow: whiteMove,
          isGameStart: _gameStart,
          lastMoveFan: fan,
          position: _gameLogic.fen,
          lastPlayedMove: relatedMove,
        );
      });
    }
  }

  String _getGameResultString() {
    if (_gameLogic.in_checkmate) {
      return _gameLogic.turn == chess.Color.WHITE ? '0-1' : '1-0';
    }
    if (_gameLogic.in_draw) {
      return '1/2-1/2';
    }
    return '*';
  }

  Widget _getGameEndedType() {
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

  void _tryMakingMove({required ShortMove move}) {
    final moveHasBeenMade = _gameLogic.move({
      'from': move.from,
      'to': move.to,
      'promotion': move.promotion.map((t) => t.name).toNullable(),
    });
    if (moveHasBeenMade) {
      setState(() {
        _addMoveToHistory();
        _gameStart = false;
      });
      if (_gameLogic.game_over) {
        final gameResultString = _getGameResultString();

        setState(() {
          _addMoveToHistory();
          _historyManager.addResultString(gameResultString);
          _whitePlayerType = PlayerType.computer;
          _blackPlayerType = PlayerType.computer;
          _gameInProgress = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _getGameEndedType(),
              ],
            ),
          ),
        );
      } else {
        _makeComputerMove();
      }
    }
  }

  Future<void> _overrideDefaultCloseHandler() async {
    await windowManager.setPreventClose(true);
    setState(() {});
  }

  Future<void> _startNewGame({
    String startPosition = chess.Chess.DEFAULT_POSITION,
    bool playerHasWhite = true,
  }) async {
    setState(() {
      _score = 0.0;
      _historyScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeIn,
      );
      _startPosition = startPosition;
      _whitePlayerType =
          playerHasWhite ? PlayerType.human : PlayerType.computer;
      _blackPlayerType =
          playerHasWhite ? PlayerType.computer : PlayerType.human;
      _orientation = playerHasWhite ? BoardColor.white : BoardColor.black;
      _gameStart = true;
      _gameInProgress = true;
      _gameLogic = chess.Chess();
      _gameLogic.load(_startPosition);
      final parts = startPosition.split(' ');
      final whiteTurn = parts[1] == 'w';
      final moveNumber = parts[5];
      final caption = "$moveNumber${whiteTurn ? '.' : '...'}";
      _lastMoveArrow = null;
      _historyManager.newGame(caption);
      _stockfishManager.startEvaluation(
        positionFen: _gameLogic.fen,
        thinkingTimeMs: _prefs.getDouble('engineThinkingTime') ?? 1000.0,
      );
    });
    _makeComputerMove();
  }

  void _toggleBoardOrientation() {
    setState(() {
      _orientation = _orientation == BoardColor.white
          ? BoardColor.black
          : BoardColor.white;
    });
  }

  Future<PieceType?> _handlePromotion() async {
    final promotion = await _showPromotionDialog(context);
    return promotion;
  }

  Future<PieceType?> _showPromotionDialog(BuildContext context) {
    const pieceSize = 60.0;
    final whiteTurn = _gameLogic.fen.split(' ')[1] == 'w';
    return showDialog<PieceType>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: I18nText('game.promotion_dialog_title'),
            alignment: Alignment.center,
            content: FittedBox(
              child: Row(
                children: [
                  InkWell(
                    child: whiteTurn
                        ? WhiteQueen(size: pieceSize)
                        : BlackQueen(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.queen),
                  ),
                  InkWell(
                    child: whiteTurn
                        ? WhiteRook(size: pieceSize)
                        : BlackRook(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.rook),
                  ),
                  InkWell(
                    child: whiteTurn
                        ? WhiteBishop(size: pieceSize)
                        : BlackBishop(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.bishop),
                  ),
                  InkWell(
                    child: whiteTurn
                        ? WhiteKnight(size: pieceSize)
                        : BlackKnight(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.knight),
                  ),
                ],
              ),
            ),
          );
        });
  }

  void _updateHistoryChildrenWidgets() {
    setState(() {
      if (_gameInProgress) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeIn,
        );
      } else {
        if (_historyManager.selectedNode != null) {
          var selectedNodeIndex = getHistoryNodeIndex(
              node: _historyManager.selectedNode!,
              rootNode: _historyManager.gameHistoryTree!);
          var selectedLine = selectedNodeIndex ~/ 6;
          _historyScrollController.animateTo(
            selectedLine * 40.0,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeIn,
          );
        } else {
          _historyScrollController.animateTo(0.0,
              duration: const Duration(milliseconds: 10), curve: Curves.easeIn);
        }
      }
    });
  }

  void _purposeStopGame() {
    if (!_gameInProgress) return;
    showDialog(
        context: context,
        builder: (BuildContext innerCtx) {
          return AlertDialog(
            title: I18nText('game.stop_game_title'),
            content: I18nText('game.stop_game_msg'),
            actions: [
              DialogActionButton(
                onPressed: _stopCurrentGameConfirmationAction,
                textContent: I18nText(
                  'buttons.ok',
                ),
                backgroundColor: Colors.tealAccent,
                textColor: Colors.white,
              ),
              DialogActionButton(
                onPressed: () => Navigator.of(context).pop(),
                textContent: I18nText(
                  'buttons.cancel',
                ),
                textColor: Colors.white,
                backgroundColor: Colors.redAccent,
              )
            ],
          );
        });
  }

  void _stopCurrentGameConfirmationAction() {
    Navigator.of(context).pop();
    _stopCurrentGame();
  }

  void _stopCurrentGame() {
    setState(() {
      if (_historyManager.currentNode?.relatedMove != null) {
        _lastMoveArrow = BoardArrow(
          from: _historyManager.currentNode!.relatedMove!.from.toString(),
          to: _historyManager.currentNode!.relatedMove!.to.toString(),
          color: Colors.blueAccent,
        );
        _historyManager.selectCurrentNode();
      }
      _historyManager.addResultString('*');
      _gameInProgress = false;
      _engineThinking = false;
      _whitePlayerType = PlayerType.computer;
      _blackPlayerType = PlayerType.computer;
    });
    setState(() {
      _historyManager.updateChildrenWidgets();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [I18nText('game.stopped')],
        ),
      ),
    );
  }

  Future<void> _goToNewGameOptionsPage() async {
    String editPosition = _gameLogic.fen;
    final editPositionEmpty = editPosition.split(' ')[0] == '8/8/8/8/8/8/8/8';
    if (editPositionEmpty) editPosition = chess.Chess.DEFAULT_POSITION;
    final gameParameters = await Navigator.of(context).pushNamed(
      '/new_game',
      arguments: NewGameScreenArguments(editPosition),
    ) as NewGameParameters?;
    if (gameParameters != null) {
      _startNewGame(
        startPosition: gameParameters.startPositionFen,
        playerHasWhite: gameParameters.playerHasWhite,
      );
    }
  }

  void _purposeRestartGame() {
    final isEmptyPosition = _gameLogic.fen == emptyPosition;
    if (isEmptyPosition) {
      _goToNewGameOptionsPage();
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext innerCtx) {
        return AlertDialog(
          title: I18nText('game.restart_game_title'),
          content: I18nText('game.restart_game_msg'),
          actions: [
            DialogActionButton(
              onPressed: () {
                Navigator.of(context).pop();
                _goToNewGameOptionsPage();
              },
              textContent: I18nText(
                'buttons.ok',
              ),
              backgroundColor: Colors.tealAccent,
              textColor: Colors.white,
            ),
            DialogActionButton(
              onPressed: () => Navigator.of(context).pop(),
              textContent: I18nText(
                'buttons.cancel',
              ),
              textColor: Colors.white,
              backgroundColor: Colors.redAccent,
            )
          ],
        );
      },
    );
  }

  void _requestGotoFirst() {
    if (_gameInProgress) return;
    setState(() {
      _lastMoveArrow = null;
      _historyManager.gotoFirst();
      _gameLogic = chess.Chess();
      _gameLogic.load(_startPosition);
      _historyManager.updateChildrenWidgets();
    });
  }

  void _selectStartPosition() {
    setState(() {
      _lastMoveArrow = null;
      _gameLogic = chess.Chess();
      _gameLogic.load(_startPosition);
    });
  }

  void _selectPosition({
    required String from,
    required String to,
    required String position,
  }) {
    setState(() {
      _lastMoveArrow = BoardArrow(
        from: from,
        to: to,
        color: Colors.blueAccent,
      );
      _gameLogic = chess.Chess();
      _gameLogic.load(position);
    });
  }

  void _requestGotoPrevious() {
    if (_gameInProgress) return;
    setState(() {
      _historyManager.gotoPrevious();
    });
  }

  void _requestGotoNext() {
    if (_gameInProgress) return;
    setState(() {
      _historyManager.gotoNext();
    });
  }

  void _requestGotoLast() {
    if (_gameInProgress) return;
    setState(() {
      _historyManager.gotoLast();
    });
  }

  Future<void> _accessSettings() async {
    if (_gameInProgress) return;
    var success = await Navigator.of(context).pushNamed('/settings');
    if (success == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              I18nText('settings.saved'),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color stockfishStatusColor;

    switch (_stockfishManager.state) {
      case StockfishState.disposed:
        stockfishStatusColor = Colors.black;
        break;
      case StockfishState.starting:
        stockfishStatusColor = Colors.orange;
        break;
      case StockfishState.ready:
        stockfishStatusColor = Colors.green;
        break;
      case StockfishState.error:
        stockfishStatusColor = Colors.red;
        break;
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        title: I18nText('app.title'),
        actions: [
          IconButton(
            onPressed: _purposeRestartGame,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _toggleBoardOrientation,
            icon: const Icon(Icons.swap_vert),
          ),
          IconButton(
            onPressed: _purposeStopGame,
            icon: const Icon(Icons.pan_tool),
          ),
          IconButton(
            onPressed: _accessSettings,
            icon: const Icon(Icons.settings),
          ),
          if (!kReleaseMode)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red,
                  width: 5.0,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _doStartStockfish,
                    icon: const Icon(
                      Icons.start,
                    ),
                  ),
                  IconButton(
                    onPressed: _stopStockfish,
                    icon: const Icon(
                      Icons.stop,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: CircleAvatar(
                      backgroundColor: stockfishStatusColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: HomePageBody(
        isLandscape: isLandscape,
        lastMoveToHighlight: _lastMoveArrow,
        engineIsThinking: _engineThinking,
        gameInProgress: _gameInProgress,
        scoreVisible: _scoreVisible,
        skillLevelEditable: _skillLevelEditable,
        skillLevel: _skillLevel,
        skillLevelMin: _skillLevelMin,
        skillLevelMax: _skillLevelMax,
        score: _score,
        positionFen: _gameLogic.fen,
        orientation: _orientation,
        whitePlayerType: _whitePlayerType,
        blackPlayerType: _blackPlayerType,
        historyElementsTree: _historyManager.elementsTree,
        scrollController: _historyScrollController,
        onMove: _tryMakingMove,
        onPromote: _handlePromotion,
        onScoreVisibleStatusChanged: (newValue) {
          if (_gameInProgress) {
            setState(() {
              _scoreVisible = newValue ?? false;
            });
            if (_scoreVisible) {
              _stockfishManager.startEvaluation(
                positionFen: _gameLogic.fen,
                thinkingTimeMs:
                    _prefs.getDouble('engineThinkingTime') ?? 1000.0,
              );
            }
          }
        },
        onSkillLevelChanged: (newValue) {
          setState(() {
            _skillLevel = newValue.toInt();
            _stockfishManager.setSkillLevel(level: _skillLevel);
          });
        },
        onGotoFirstRequest: _requestGotoFirst,
        onGotoPreviousRequest: _requestGotoPrevious,
        onGotoNextRequest: _requestGotoNext,
        onGotoLastRequest: _requestGotoLast,
      ),
    );
  }
}
