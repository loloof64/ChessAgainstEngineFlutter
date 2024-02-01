import 'dart:async';

import 'package:chess_against_engine/logic/managers/game_manager.dart';
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
import '../screens/home_screen_widgets.dart';
import '../screens/new_game_screen.dart';

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
  late StockfishManager _stockfishManager;
  late SharedPreferences _prefs;

  @override
  void initState() {
    windowManager.addListener(this);
    _overrideDefaultCloseHandler();
    HistoryManager().addPositionSelectedCallback(_selectPosition);
    HistoryManager().addStartPositionSelectedCallback(_selectStartPosition);
    HistoryManager()
        .addUpdateChildrenWidgetsCallback(_updateHistoryChildrenWidgets);
    _stockfishManager = StockfishManager(
      setSkillLevelOption: _setSkillLevelOption,
      unsetSkillLevelOption: _unsetSkillLevelOption,
      handleReadyOk: _makeComputerMove,
      handleScoreCp: _handleScoreCp,
      onBestMove: _processBestMove,
    );
    _doStartStockfish();
    _initPreferences();
    super.initState();
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
    HistoryManager().removePositionSelectedCallback(_selectPosition);
    HistoryManager().removeStartPositionSelectedCallback(_selectStartPosition);
    HistoryManager()
        .removeUpdateChildrenWidgetsCallback(_updateHistoryChildrenWidgets);
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
    if (!GameManager().currentState.cpuCanPlay) return;
    if (!GameManager().currentState.gameInProgress) return;

    final moveHasBeenMade = GameManager().processComputerMove(
      from: from,
      to: to,
      promotion: promotion,
    );

    if (!moveHasBeenMade) return;

    setState(() {
      _lastMoveArrow = BoardArrow(from: from, to: to, color: Colors.blueAccent);
    });
    _addMoveToHistory();
    GameManager().clearGameStartFlag();

    if (GameManager().currentState.gameOver) {
      final gameResultString = GameManager().getResultString();

      GameManager().stopGame();
      HistoryManager().addResultString(gameResultString);
      HistoryManager().gotoLast();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameManager().getGameEndedType(),
            ],
          ),
        ),
      );
    }

    HistoryManager().updateChildrenWidgets();
    _makeComputerMove();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _makeComputerMove() {
    if (!GameManager().currentState.gameInProgress) return;
    final whiteTurn = GameManager().currentState.whiteTurn;
    final computerTurn = (whiteTurn &&
            GameManager().currentState.whitePlayerType ==
                PlayerType.computer) ||
        (!whiteTurn &&
            GameManager().currentState.blackPlayerType == PlayerType.computer);
    if (!computerTurn) return;

    GameManager().allowCpuThinking();
    _stockfishManager.startEvaluation(
      positionFen: GameManager().currentState.positionFen,
      thinkingTimeMs: _prefs.getDouble('engineThinkingTime') ?? 1000.0,
    );
  }

  void _handleScoreCp({required double scoreCp}) {
    final cpuHasBlack =
        GameManager().currentState.whitePlayerType == PlayerType.human &&
            GameManager().currentState.blackPlayerType == PlayerType.computer;
    final cpuTurnAsBlack = cpuHasBlack && GameManager().currentState.cpuCanPlay;
    var realScore = scoreCp;
    if (cpuTurnAsBlack) {
      realScore *= -1;
    }
    GameManager().updateScore(realScore);
  }

  /*
    Must be called after a move has just been
    added to _gameLogic
    Do not update state itself.
  */
  void _addMoveToHistory() {
    if (HistoryManager().currentNode != null) {
      final whiteMove = GameManager().currentState.whiteTurn;
      final lastMoveFan = GameManager().getLastMoveFan();
      final relatedMove = GameManager().getLastMove();
      final gameStart = GameManager().currentState.gameStart;
      final position = GameManager().currentState.positionFen;

      setState(() {
        _lastMoveArrow = BoardArrow(
            from: relatedMove.from.toString(),
            to: relatedMove.to.toString(),
            color: Colors.blueAccent);
      });
      HistoryManager().addMove(
        isWhiteTurnNow: whiteMove,
        isGameStart: gameStart,
        lastMoveFan: lastMoveFan,
        position: position,
        lastPlayedMove: relatedMove,
      );
    }
  }

  void _tryMakingMove({required ShortMove move}) {
    setState(() {
      final moveHasBeenMade = GameManager().processPlayerMove(
        from: move.from,
        to: move.to,
        promotion: move.promotion.map((t) => t.name).toNullable(),
      );
      if (moveHasBeenMade) {
        _addMoveToHistory();
      }
      GameManager().clearGameStartFlag();
    });
    if (GameManager().currentState.gameOver) {
      final gameResultString = GameManager().getResultString();

      _addMoveToHistory();
      HistoryManager().addResultString(gameResultString);
      GameManager().stopGame();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameManager().getGameEndedType(),
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
      HistoryManager().newGame(caption);
      GameManager().startNewGame(
        startPosition: startPosition,
        playerHasWhite: playerHasWhite,
      );
      _stockfishManager.startEvaluation(
        positionFen: GameManager().currentState.positionFen,
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
    final whiteTurn =
        GameManager().currentState.positionFen.split(' ')[1] == 'w';
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
      if (GameManager().currentState.gameInProgress) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeIn,
        );
      } else {
        if (HistoryManager().selectedNode != null) {
          var selectedNodeIndex = getHistoryNodeIndex(
              node: HistoryManager().selectedNode!,
              rootNode: HistoryManager().gameHistoryTree!);
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
    if (!GameManager().currentState.gameInProgress) return;
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
    if (HistoryManager().currentNode?.relatedMove != null) {
      _lastMoveArrow = BoardArrow(
        from: HistoryManager().currentNode!.relatedMove!.from.toString(),
        to: HistoryManager().currentNode!.relatedMove!.to.toString(),
        color: Colors.blueAccent,
      );
      HistoryManager().selectCurrentNode();
    }
    HistoryManager().addResultString('*');
    GameManager().stopGame();
    HistoryManager().updateChildrenWidgets();
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
    String editPosition = GameManager().currentState.positionFen;
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
    final isEmptyPosition =
        GameManager().currentState.positionFen == emptyPosition;
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
    if (GameManager().currentState.gameInProgress) return;
    setState(() {
      _lastMoveArrow = null;
    });
    HistoryManager().gotoFirst();
    GameManager().loadStartPosition();
    HistoryManager().updateChildrenWidgets();
  }

  void _selectStartPosition() {
    if (GameManager().currentState.gameInProgress) return;
    setState(() {
      _lastMoveArrow = null;
    });
    GameManager().loadStartPosition();
  }

  void _selectPosition({
    required String from,
    required String to,
    required String position,
  }) {
    if (GameManager().currentState.gameInProgress) return;
    setState(() {
      _lastMoveArrow = BoardArrow(
        from: from,
        to: to,
        color: Colors.blueAccent,
      );
    });
    GameManager().loadPosition(position);
  }

  void _requestGotoPrevious() {
    if (GameManager().currentState.gameInProgress) return;
    HistoryManager().gotoPrevious();
  }

  void _requestGotoNext() {
    if (GameManager().currentState.gameInProgress) return;
    HistoryManager().gotoNext();
  }

  void _requestGotoLast() {
    if (GameManager().currentState.gameInProgress) return;
    HistoryManager().gotoLast();
  }

  Future<void> _accessSettings() async {
    if (GameManager().currentState.gameInProgress) return;
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
      body: ValueListenableBuilder(
        valueListenable: GameManager(),
        builder: (BuildContext context, GameState gameState, Widget? child) {
          return HomePageBody(
            isLandscape: isLandscape,
            lastMoveToHighlight: _lastMoveArrow,
            engineIsThinking: gameState.engineThinking,
            gameInProgress: gameState.gameInProgress,
            scoreVisible: _scoreVisible,
            skillLevelEditable: _skillLevelEditable,
            skillLevel: _skillLevel,
            skillLevelMin: _skillLevelMin,
            skillLevelMax: _skillLevelMax,
            score: gameState.score,
            positionFen: gameState.positionFen,
            orientation: _orientation,
            whitePlayerType: gameState.whitePlayerType,
            blackPlayerType: gameState.blackPlayerType,
            historyElementsTree: HistoryManager().elementsTree,
            scrollController: _historyScrollController,
            onMove: _tryMakingMove,
            onPromote: _handlePromotion,
            onScoreVisibleStatusChanged: (newValue) {
              if (gameState.gameInProgress) {
                setState(() {
                  _scoreVisible = newValue ?? false;
                });
                if (_scoreVisible) {
                  _stockfishManager.startEvaluation(
                    positionFen: gameState.positionFen,
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
          );
        },
      ),
    );
  }
}
