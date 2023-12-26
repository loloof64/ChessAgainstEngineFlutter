import 'dart:async';

import 'package:chess_against_engine/logic/managers/game_manager.dart';
import 'package:chess_against_engine/logic/managers/history_manager.dart';
import 'package:chess_against_engine/logic/managers/stockfish_manager.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_against_engine/stores/stockfish_manager.dart';
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
import '../screens/home_screen_widgets.dart';
import '../screens/new_game_screen.dart';

final stockfishManager = StockfishManagerStore();

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  BoardColor _orientation = BoardColor.white;
  bool _skillLevelEditable = false;
  int _skillLevel = -1;
  int _skillLevelMin = -1;
  int _skillLevelMax = -1;
  bool _scoreVisible = false;

  final ScrollController _historyScrollController =
      ScrollController(initialScrollOffset: 0.0, keepScrollOffset: true);
  BoardArrow? _lastMoveArrow;
  late SharedPreferences _prefs;
  late HistoryManager _historyManager;
  late GameManager _gameManager;

  @override
  void initState() {
    windowManager.addListener(this);
    _overrideDefaultCloseHandler();
    stockfishManager.setManager(
      StockfishManager(
        setSkillLevelOption: _setSkillLevelOption,
        unsetSkillLevelOption: _unsetSkillLevelOption,
        handleReadyOk: _makeComputerMove,
        handleScoreCp: _handleScoreCp,
        onBestMove: _processBestMove,
      ),
    );
    _historyManager = HistoryManager(
      onUpdateChildrenWidgets: _updateHistoryChildrenWidgets,
      onPositionSelected: _selectPosition,
      onSelectStartPosition: _selectStartPosition,
      isStartMoveNumber: _isStartMoveNumber,
    );
    _gameManager = GameManager();
    _doStartStockfish();
    _initPreferences();
    super.initState();
  }

  bool _isStartMoveNumber(int moveNumber) {
    return int.parse(_gameManager.startPosition.split(' ')[5]) == moveNumber;
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
      stockfishManager.manager?.start();
    });
  }

  void _stopStockfish() async {
    setState(() {
      stockfishManager.manager?.stop();
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
    if (!_gameManager.cpuCanPlay) return;
    if (!_gameManager.gameInProgress) return;

    setState(() {
      final moveHasBeenMade = _gameManager.processComputerMove(
        from: from,
        to: to,
        promotion: promotion,
      );

      if (!moveHasBeenMade) return;
    });

    setState(() {
      _lastMoveArrow = BoardArrow(from: from, to: to, color: Colors.blueAccent);
      _addMoveToHistory();
      _gameManager.clearGameStartFlag();
    });

    if (_gameManager.isGameOver) {
      final gameResultString = _gameManager.getResultString();

      setState(() {
        _gameManager.stopGame();
        _historyManager.addResultString(gameResultString);
        _historyManager.gotoLast();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _gameManager.getGameEndedType(),
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
    if (!_gameManager.gameInProgress) return;
    final whiteTurn = _gameManager.whiteTurn;
    final computerTurn =
        (whiteTurn && _gameManager.whitePlayerType == PlayerType.computer) ||
            (!whiteTurn && _gameManager.blackPlayerType == PlayerType.computer);
    if (!computerTurn) return;

    setState(() {
      _gameManager.allowCpuThinking();
      stockfishManager.manager?.startEvaluation(
        positionFen: _gameManager.position,
        thinkingTimeMs: _prefs.getDouble('engineThinkingTime') ?? 1000.0,
      );
    });
  }

  void _handleScoreCp({required double scoreCp}) {
    final cpuHasBlack = _gameManager.whitePlayerType == PlayerType.human &&
        _gameManager.blackPlayerType == PlayerType.computer;
    final cpuTurnAsBlack = cpuHasBlack && _gameManager.cpuCanPlay;
    var realScore = scoreCp;
    if (cpuTurnAsBlack) {
      realScore *= -1;
    }
    setState(() {
      _gameManager.updateScore(realScore);
    });
  }

  /*
    Must be called after a move has just been
    added to _gameLogic
    Do not update state itself.
  */
  void _addMoveToHistory() {
    if (_historyManager.currentNode != null) {
      final whiteMove = _gameManager.whiteTurn;
      final lastMoveFan = _gameManager.getLastMoveFan();
      final relatedMove = _gameManager.getLastMove();
      final gameStart = _gameManager.isGameStart;
      final position = _gameManager.position;

      setState(() {
        _lastMoveArrow = BoardArrow(
            from: relatedMove.from.toString(),
            to: relatedMove.to.toString(),
            color: Colors.blueAccent);
        _historyManager.addMove(
          isWhiteTurnNow: whiteMove,
          isGameStart: gameStart,
          lastMoveFan: lastMoveFan,
          position: position,
          lastPlayedMove: relatedMove,
        );
      });
    }
  }

  void _tryMakingMove({required ShortMove move}) {
    setState(() {
      final moveHasBeenMade = _gameManager.processPlayerMove(
        from: move.from,
        to: move.to,
        promotion: move.promotion.map((t) => t.name).toNullable(),
      );
      if (moveHasBeenMade) {
        _addMoveToHistory();
      }
      _gameManager.clearGameStartFlag();
    });
    if (_gameManager.isGameOver) {
      final gameResultString = _gameManager.getResultString();

      setState(() {
        _addMoveToHistory();
        _historyManager.addResultString(gameResultString);
        _gameManager.stopGame();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _gameManager.getGameEndedType(),
            ],
          ),
        ),
      );
    } else {
      _makeComputerMove();
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
      _historyScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeIn,
      );

      _orientation = playerHasWhite ? BoardColor.white : BoardColor.black;

      final parts = startPosition.split(' ');
      final whiteTurn = parts[1] == 'w';
      final moveNumber = parts[5];
      final caption = "$moveNumber${whiteTurn ? '.' : '...'}";
      _lastMoveArrow = null;
      _historyManager.newGame(caption);
      _gameManager.startNewGame(
        startPosition: startPosition,
        playerHasWhite: playerHasWhite,
      );
      stockfishManager.manager?.startEvaluation(
        positionFen: _gameManager.position,
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
    final whiteTurn = _gameManager.position.split(' ')[1] == 'w';
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
      if (_gameManager.gameInProgress) {
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
    if (!_gameManager.gameInProgress) return;
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
      _gameManager.stopGame();
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
    String editPosition = _gameManager.position;
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
    final isEmptyPosition = _gameManager.position == emptyPosition;
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
    if (_gameManager.gameInProgress) return;
    setState(() {
      _lastMoveArrow = null;
      _historyManager.gotoFirst();
      _gameManager.loadStartPosition();
      _historyManager.updateChildrenWidgets();
    });
  }

  void _selectStartPosition() {
    setState(() {
      _lastMoveArrow = null;
      _gameManager.loadStartPosition();
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
      _gameManager.loadPosition(position);
    });
  }

  void _requestGotoPrevious() {
    if (_gameManager.gameInProgress) return;
    setState(() {
      _historyManager.gotoPrevious();
    });
  }

  void _requestGotoNext() {
    if (_gameManager.gameInProgress) return;
    setState(() {
      _historyManager.gotoNext();
    });
  }

  void _requestGotoLast() {
    if (_gameManager.gameInProgress) return;
    setState(() {
      _historyManager.gotoLast();
    });
  }

  Future<void> _accessSettings() async {
    if (_gameManager.gameInProgress) return;
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

    switch (stockfishManager.manager?.state ?? StockfishState.disposed) {
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
            PopupMenuButton<int>(onSelected: (int item) {
              switch (item) {
                case 0:
                  _doStartStockfish();
                  break;
                case 1:
                  _stopStockfish();
                  break;
              }
            }, itemBuilder: (BuildContext context) {
              return <PopupMenuItem<int>>[
                const PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(
                        Icons.start,
                        color: Colors.green,
                      ),
                      Text(
                        'Start stockfish',
                        style: TextStyle(
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(
                        Icons.stop,
                        color: Colors.red,
                      ),
                      Text(
                        'Stop stockfish',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: CircleAvatar(
                    backgroundColor: stockfishStatusColor,
                  ),
                )
              ];
            }),
        ],
      ),
      body: HomePageBody(
        isLandscape: isLandscape,
        lastMoveToHighlight: _lastMoveArrow,
        engineIsThinking: _gameManager.engineThiking,
        gameInProgress: _gameManager.gameInProgress,
        scoreVisible: _scoreVisible,
        skillLevelEditable: _skillLevelEditable,
        skillLevel: _skillLevel,
        skillLevelMin: _skillLevelMin,
        skillLevelMax: _skillLevelMax,
        score: _gameManager.score,
        positionFen: _gameManager.position,
        orientation: _orientation,
        whitePlayerType: _gameManager.whitePlayerType,
        blackPlayerType: _gameManager.blackPlayerType,
        historyElementsTree: _historyManager.elementsTree,
        scrollController: _historyScrollController,
        onMove: _tryMakingMove,
        onPromote: _handlePromotion,
        onScoreVisibleStatusChanged: (newValue) {
          if (_gameManager.gameInProgress) {
            setState(() {
              _scoreVisible = newValue ?? false;
            });
            if (_scoreVisible) {
               stockfishManager.manager?.startEvaluation(
                positionFen: _gameManager.position,
                thinkingTimeMs:
                    _prefs.getDouble('engineThinkingTime') ?? 1000.0,
              );
            }
          }
        },
        onSkillLevelChanged: (newValue) {
          setState(() {
            _skillLevel = newValue.toInt();
            stockfishManager.manager?.setSkillLevel(level: _skillLevel);
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
