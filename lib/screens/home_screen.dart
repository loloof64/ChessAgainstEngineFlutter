import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:stockfish_chess_engine/stockfish.dart';
import 'package:stockfish_chess_engine/stockfish_state.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_chess_board/models/board_arrow.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:chess_loloof64/chess_loloof64.dart' as chess;
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/dialog_buttons.dart';
import '../components/history.dart';
import '../logic/history/history_builder.dart' hide File;
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
  HistoryNode? _gameHistoryTree;
  HistoryNode? _currentGameHistoryNode;
  HistoryNode? _selectedHistoryNode;
  List<HistoryElement> _historyElementsTree = [];
  bool _cpuCanPlay = false;
  String _startPosition = chess.Chess.DEFAULT_POSITION;
  bool _gameStart = false;
  bool _gameInProgress = false;
  bool _skillLevelEditable = false;
  int _skillLevel = -1;
  int _skillLevelDefault = -1;
  int _skillLevelMin = -1;
  int _skillLevelMax = -1;
  bool _engineThinking = false;
  bool _scoreVisible = false;
  double _score = 0.0;
  final ScrollController _historyScrollController =
      ScrollController(initialScrollOffset: 0.0, keepScrollOffset: true);
  BoardArrow? _lastMoveArrow;
  late SharedPreferences _prefs;
  late Stockfish _stockfish;
  late StreamSubscription<String> _stockfishOutputSubsciption;

  @override
  void initState() {
    windowManager.addListener(this);
    _overrideDefaultCloseHandler();
    _doStartStockfish();
    _gameLogic.load(emptyPosition);
    _initPreferences();
    super.initState();
  }

  void _doStartStockfish() async {
    _stockfish = Stockfish();
    _stockfishOutputSubsciption = _stockfish.stdout.listen((message) {
      _processEngineStdOut(message);
    });
    await Future.delayed(const Duration(milliseconds: 800));
    _stockfish.stdin = 'uci';
    await Future.delayed(const Duration(milliseconds: 200));
    _stockfish.stdin = 'isready';
    await Future.delayed(const Duration(milliseconds: 50));
    setState(() {});
  }

  void _stopStockfish() async {
    if (_stockfish.state.value == StockfishState.disposed ||
        _stockfish.state.value == StockfishState.error) {
      return;
    }
    _stockfishOutputSubsciption.cancel();
    _stockfish.stdin = 'quit';
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {});
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

  void _processEngineBestMoveMessage(String message) {
    if (!_gameInProgress) return;
    final bestMoveIndex = message.indexOf("bestmove");
    final bestMoveMessage = message.substring(bestMoveIndex);
    final parts = bestMoveMessage.split(" ");
    final moveAlgebraic = parts[1];
    final from = moveAlgebraic.substring(0, 2);
    final to = moveAlgebraic.substring(2, 4);
    final promotion =
        moveAlgebraic.length > 4 ? moveAlgebraic.substring(4, 5) : null;

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
      final nextHistoryNode = HistoryNode(caption: gameResultString);

      setState(() {
        _selectedHistoryNode = _currentGameHistoryNode;
        _lastMoveArrow = BoardArrow(
          from: _currentGameHistoryNode!.relatedMove!.from.toString(),
          to: _currentGameHistoryNode!.relatedMove!.to.toString(),
          color: Colors.blueAccent,
        );
        _currentGameHistoryNode?.next = nextHistoryNode;
        _currentGameHistoryNode = nextHistoryNode;
      });
      _updateHistoryChildrenWidgets();

      setState(() {
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

    _updateHistoryChildrenWidgets();
    _makeComputerMove();
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

        setState(() {
          _skillLevelEditable = true;
          _skillLevelDefault = defaultLevel;
          _skillLevelMin = minLevel;
          _skillLevelMax = maxLevel;
          _skillLevel = _skillLevelDefault;
        });
      } else {
        setState(() {
          _skillLevelEditable = false;
        });
      }
    }
    if (message.contains("uciok")) {
      _stockfish.stdin = 'isready';
      return;
    }
    if (message.contains("readyok")) {
      _makeComputerMove();
      return;
    }
    if (message.contains("score cp")) {
      final cpuHasBlack = _whitePlayerType == PlayerType.human &&
          _blackPlayerType == PlayerType.computer;
      final cpuTurnAsBlack = cpuHasBlack && _cpuCanPlay;
      final scores = RegExp(r"score cp ([0-9-]+)")
          .allMatches(message)
          .map((e) => e.group(1))
          .map((e) => int.parse(e!) / 100.0);
      for (var score in scores) {
        var realScore = score;
        if (cpuTurnAsBlack) {
          realScore *= -1;
        }
        setState(() {
          _score = realScore;
        });
      }
    }
    if (message.contains("bestmove") && _cpuCanPlay) {
      _processEngineBestMoveMessage(message);
    }
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
    });
    _startEngineEvaluation();
  }

  /*
    Must be called after a move has just been
    added to _gameLogic
    Do not update state itself.
  */
  void _addMoveToHistory() {
    if (_currentGameHistoryNode != null) {
      final whiteMove = _gameLogic.turn == chess.Color.WHITE;
      final lastPlayedMove = _gameLogic.history.last.move;

      /*
      We need to know if it was white move before the move which
      we want to add history node(s).
      */
      if (!whiteMove && !_gameStart) {
        final moveNumberCaption = "${_gameLogic.fen.split(' ')[5]}.";
        final nextHistoryNode = HistoryNode(caption: moveNumberCaption);
        _currentGameHistoryNode?.next = nextHistoryNode;
        _currentGameHistoryNode = nextHistoryNode;
      }

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

      final nextHistoryNode = HistoryNode(
        caption: fan,
        fen: _gameLogic.fen,
        relatedMove: relatedMove,
      );
      setState(() {
        _currentGameHistoryNode?.next = nextHistoryNode;
        _currentGameHistoryNode = nextHistoryNode;
      });
      _updateHistoryChildrenWidgets();
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
        final nextHistoryNode = HistoryNode(caption: gameResultString);

        setState(() {
          _selectedHistoryNode = _currentGameHistoryNode;
          _lastMoveArrow = BoardArrow(
            from: _currentGameHistoryNode!.relatedMove!.from.toString(),
            to: _currentGameHistoryNode!.relatedMove!.to.toString(),
            color: Colors.blueAccent,
          );
          _currentGameHistoryNode?.next = nextHistoryNode;
          _currentGameHistoryNode = nextHistoryNode;
        });
        _updateHistoryChildrenWidgets();

        setState(() {
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

  Future<void> _startEngineEvaluation() async {
    await Future.delayed(const Duration(seconds: 1));
    _stockfish.stdin = "position fen ${_gameLogic.fen}";
    _stockfish.stdin =
        "go movetime ${_prefs.getDouble('engineThinkingTime') ?? 1000.0}";
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
      _selectedHistoryNode = null;
      _gameHistoryTree = HistoryNode(caption: caption);
      _currentGameHistoryNode = _gameHistoryTree;
    });
    _updateHistoryChildrenWidgets();
    _startEngineEvaluation();
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
      if (_gameHistoryTree != null) {
        _historyElementsTree = recursivelyBuildElementsFromHistoryTree(
          fontSize: 40,
          selectedHistoryNode: _selectedHistoryNode,
          tree: _gameHistoryTree!,
          onHistoryMoveRequested: onHistoryMoveRequested,
        );
      }
      if (_gameInProgress) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeIn,
        );
      } else {
        if (_selectedHistoryNode != null) {
          var selectedNodeIndex = getHistoryNodeIndex(
              node: _selectedHistoryNode!, rootNode: _gameHistoryTree!);
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
    final nextHistoryNode = HistoryNode(caption: '*');
    setState(() {
      if (_currentGameHistoryNode?.relatedMove != null) {
        _lastMoveArrow = BoardArrow(
          from: _currentGameHistoryNode!.relatedMove!.from.toString(),
          to: _currentGameHistoryNode!.relatedMove!.to.toString(),
          color: Colors.blueAccent,
        );
        _selectedHistoryNode = _currentGameHistoryNode;
      }
      _currentGameHistoryNode?.next = nextHistoryNode;
      _currentGameHistoryNode = nextHistoryNode;
      _gameInProgress = false;
      _engineThinking = false;
      _whitePlayerType = PlayerType.computer;
      _blackPlayerType = PlayerType.computer;
    });
    _updateHistoryChildrenWidgets();
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

  void onHistoryMoveRequested({
    required Move historyMove,
    required HistoryNode? selectedHistoryNode,
  }) {
    if (_gameInProgress) return;
    setState(() {
      _selectedHistoryNode = selectedHistoryNode;
      _lastMoveArrow = BoardArrow(
        from: _selectedHistoryNode!.relatedMove!.from.toString(),
        to: _selectedHistoryNode!.relatedMove!.to.toString(),
        color: Colors.blueAccent,
      );
      _gameLogic = chess.Chess();
      _gameLogic.load(
        selectedHistoryNode!.fen!,
      );
    });
    _updateHistoryChildrenWidgets();
  }

  void _requestGotoFirst() {
    if (_gameInProgress) return;
    setState(() {
      _lastMoveArrow = null;
      _selectedHistoryNode = null;
      _gameLogic = chess.Chess();
      _gameLogic.load(_startPosition);
    });
    _updateHistoryChildrenWidgets();
  }

  void _requestGotoPrevious() {
    if (_gameInProgress) return;
    var previousNode = _gameHistoryTree;
    var newSelectedNode = previousNode;
    if (previousNode != null) {
      while (previousNode?.next != _selectedHistoryNode) {
        previousNode = previousNode?.next != null
            ? HistoryNode.from(previousNode!.next!)
            : null;
        if (previousNode?.relatedMove != null) newSelectedNode = previousNode;
      }
      if (newSelectedNode?.relatedMove != null) {
        setState(() {
          _lastMoveArrow = BoardArrow(
            from: newSelectedNode!.relatedMove!.from.toString(),
            to: newSelectedNode.relatedMove!.to.toString(),
            color: Colors.blueAccent,
          );
          _selectedHistoryNode = newSelectedNode;
          _gameLogic = chess.Chess();
          _gameLogic.load(newSelectedNode.fen!);
        });
        _updateHistoryChildrenWidgets();
      }
    }
  }

  void _requestGotoNext() {
    if (_gameInProgress) return;
    var nextNode = _selectedHistoryNode != null
        ? _selectedHistoryNode!.next
        : _gameHistoryTree;
    if (nextNode != null) {
      while (nextNode != null && nextNode.relatedMove == null) {
        nextNode = nextNode.next;
      }
      if (nextNode != null && nextNode.relatedMove != null) {
        setState(() {
          _lastMoveArrow = BoardArrow(
            from: nextNode!.relatedMove!.from.toString(),
            to: nextNode.relatedMove!.to.toString(),
            color: Colors.blueAccent,
          );
          _selectedHistoryNode = nextNode;
          _gameLogic = chess.Chess();
          _gameLogic.load(nextNode.fen!);
        });
        _updateHistoryChildrenWidgets();
      }
    }
  }

  void _requestGotoLast() {
    if (_gameInProgress) return;
    var nextNode = _selectedHistoryNode != null
        ? _selectedHistoryNode!.next
        : _gameHistoryTree;
    var newSelectedNode = nextNode;

    while (true) {
      nextNode =
          nextNode?.next != null ? HistoryNode.from(nextNode!.next!) : null;
      if (nextNode == null) break;
      if (nextNode.fen != null) {
        newSelectedNode = nextNode;
      }
    }

    setState(() {
      _lastMoveArrow = BoardArrow(
        from: newSelectedNode!.relatedMove!.from.toString(),
        to: newSelectedNode.relatedMove!.to.toString(),
        color: Colors.blueAccent,
      );
      _selectedHistoryNode = newSelectedNode;
    });
    _updateHistoryChildrenWidgets();
    _gameLogic = chess.Chess();
    _gameLogic.load(newSelectedNode!.fen!);
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      appBar: _buildAppBar(),
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
        historyElementsTree: _historyElementsTree,
        scrollController: _historyScrollController,
        onMove: _tryMakingMove,
        onPromote: _handlePromotion,
        onScoreVisibleStatusChanged: (newValue) {
          if (_gameInProgress) {
            setState(() {
              _scoreVisible = newValue ?? false;
            });
            if (_scoreVisible) {
              _startEngineEvaluation();
            }
          }
        },
        onSkillLevelChanged: (newValue) {
          setState(() {
            _skillLevel = newValue.toInt();
            _stockfish.stdin = 'setoption name Skill Level value $_skillLevel';
          });
        },
        onGotoFirstRequest: _requestGotoFirst,
        onGotoPreviousRequest: _requestGotoPrevious,
        onGotoNextRequest: _requestGotoNext,
        onGotoLastRequest: _requestGotoLast,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    Color stockfishStatusColor;

    switch (_stockfish.state.value) {
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

    return AppBar(
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
    );
  }
}

class HomePageBody extends StatelessWidget {
  final bool isLandscape;
  final bool engineIsThinking;
  final bool gameInProgress;
  final bool scoreVisible;
  final bool skillLevelEditable;
  final int skillLevel;
  final int skillLevelMin;
  final int skillLevelMax;
  final double score;
  final String positionFen;
  final BoardArrow? lastMoveToHighlight;
  final BoardColor orientation;
  final PlayerType whitePlayerType;
  final PlayerType blackPlayerType;
  final List<HistoryElement> historyElementsTree;
  final ScrollController scrollController;
  final void Function({required ShortMove move}) onMove;
  final Future<PieceType?> Function() onPromote;
  final void Function(bool? newValue) onScoreVisibleStatusChanged;
  final void Function(double newValue) onSkillLevelChanged;
  final void Function() onGotoFirstRequest;
  final void Function() onGotoPreviousRequest;
  final void Function() onGotoNextRequest;
  final void Function() onGotoLastRequest;

  const HomePageBody({
    super.key,
    this.lastMoveToHighlight,
    required this.isLandscape,
    required this.engineIsThinking,
    required this.gameInProgress,
    required this.scoreVisible,
    required this.skillLevelEditable,
    required this.skillLevel,
    required this.skillLevelMin,
    required this.skillLevelMax,
    required this.score,
    required this.positionFen,
    required this.orientation,
    required this.whitePlayerType,
    required this.blackPlayerType,
    required this.historyElementsTree,
    required this.scrollController,
    required this.onMove,
    required this.onPromote,
    required this.onScoreVisibleStatusChanged,
    required this.onSkillLevelChanged,
    required this.onGotoFirstRequest,
    required this.onGotoPreviousRequest,
    required this.onGotoNextRequest,
    required this.onGotoLastRequest,
  });

  @override
  Widget build(BuildContext context) {
    const commonDiviserSize = 30.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLandscape
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HomePageChessboardZone(
                    engineIsThinking: engineIsThinking,
                    positionFen: positionFen,
                    orientation: orientation,
                    whitePlayerType: whitePlayerType,
                    blackPlayerType: blackPlayerType,
                    onMove: onMove,
                    onPromote: onPromote,
                  ),
                  const SizedBox(
                    width: commonDiviserSize,
                  ),
                  HomePageInformationZone(
                    gameInProgress: gameInProgress,
                    scoreVisible: scoreVisible,
                    skillLevelEditable: skillLevelEditable,
                    skillLevel: skillLevel,
                    skillLevelMin: skillLevelMin,
                    skillLevelMax: skillLevelMax,
                    score: score,
                    historyElementsTree: historyElementsTree,
                    scrollController: scrollController,
                    onScoreVisibleStatusChanged: onScoreVisibleStatusChanged,
                    onSkillLevelChanged: onSkillLevelChanged,
                    onGotoFirstRequest: onGotoFirstRequest,
                    onGotoPreviousRequest: onGotoPreviousRequest,
                    onGotoNextRequest: onGotoNextRequest,
                    onGotoLastRequest: onGotoLastRequest,
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HomePageChessboardZone(
                    engineIsThinking: engineIsThinking,
                    positionFen: positionFen,
                    orientation: orientation,
                    whitePlayerType: whitePlayerType,
                    blackPlayerType: blackPlayerType,
                    onMove: onMove,
                    onPromote: onPromote,
                  ),
                  const SizedBox(
                    height: commonDiviserSize,
                  ),
                  HomePageInformationZone(
                    gameInProgress: gameInProgress,
                    scoreVisible: scoreVisible,
                    skillLevelEditable: skillLevelEditable,
                    skillLevel: skillLevel,
                    skillLevelMin: skillLevelMin,
                    skillLevelMax: skillLevelMax,
                    score: score,
                    historyElementsTree: historyElementsTree,
                    scrollController: scrollController,
                    onScoreVisibleStatusChanged: onScoreVisibleStatusChanged,
                    onSkillLevelChanged: onSkillLevelChanged,
                    onGotoFirstRequest: onGotoFirstRequest,
                    onGotoPreviousRequest: onGotoPreviousRequest,
                    onGotoNextRequest: onGotoNextRequest,
                    onGotoLastRequest: onGotoLastRequest,
                  ),
                ],
              ),
      ),
    );
  }
}

class HomePageChessboardZone extends StatelessWidget {
  final bool engineIsThinking;
  final String positionFen;
  final BoardArrow? lastMoveToHighlight;
  final BoardColor orientation;
  final PlayerType whitePlayerType;
  final PlayerType blackPlayerType;
  final void Function({required ShortMove move}) onMove;
  final Future<PieceType?> Function() onPromote;

  const HomePageChessboardZone({
    super.key,
    this.lastMoveToHighlight,
    required this.engineIsThinking,
    required this.positionFen,
    required this.orientation,
    required this.whitePlayerType,
    required this.blackPlayerType,
    required this.onMove,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx2, constraints) {
      final availableBoardSize = constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;
      return SizedBox(
        height: availableBoardSize,
        child: Stack(
          children: [
            SimpleChessBoard(
                lastMoveToHighlight: lastMoveToHighlight,
                fen: positionFen,
                orientation: orientation,
                whitePlayerType: whitePlayerType,
                blackPlayerType: blackPlayerType,
                onMove: onMove,
                onPromote: onPromote),
            if (engineIsThinking)
              Center(
                child: SizedBox(
                  width: availableBoardSize,
                  height: availableBoardSize,
                  child: const CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class HomePageInformationZone extends StatelessWidget {
  final bool gameInProgress;
  final bool scoreVisible;
  final bool skillLevelEditable;
  final int skillLevel;
  final int skillLevelMin;
  final int skillLevelMax;
  final double score;
  final List<HistoryElement> historyElementsTree;
  final ScrollController scrollController;

  final void Function(bool? newValue) onScoreVisibleStatusChanged;
  final void Function(double newValue) onSkillLevelChanged;
  final void Function() onGotoFirstRequest;
  final void Function() onGotoPreviousRequest;
  final void Function() onGotoNextRequest;
  final void Function() onGotoLastRequest;

  const HomePageInformationZone({
    super.key,
    required this.gameInProgress,
    required this.scoreVisible,
    required this.skillLevelEditable,
    required this.skillLevel,
    required this.skillLevelMin,
    required this.skillLevelMax,
    required this.score,
    required this.historyElementsTree,
    required this.scrollController,
    required this.onScoreVisibleStatusChanged,
    required this.onSkillLevelChanged,
    required this.onGotoFirstRequest,
    required this.onGotoPreviousRequest,
    required this.onGotoNextRequest,
    required this.onGotoLastRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HomePageEvaluationZone(
            gameInProgress: gameInProgress,
            scoreVisible: scoreVisible,
            skillLevelEditable: skillLevelEditable,
            score: score,
            skillLevel: skillLevel,
            skillLevelMin: skillLevelMin,
            skillLevelMax: skillLevelMax,
            onScoreVisibleStatusChanged: onScoreVisibleStatusChanged,
            onSkillLevelChanged: onSkillLevelChanged,
          ),
          HomePageHistoryZone(
            historyElementsTree: historyElementsTree,
            scrollController: scrollController,
            onGotoFirstRequest: onGotoFirstRequest,
            onGotoPreviousRequest: onGotoPreviousRequest,
            onGotoNextRequest: onGotoNextRequest,
            onGotoLastRequest: onGotoLastRequest,
          ),
        ],
      ),
    );
  }
}

class HomePageEvaluationZone extends StatelessWidget {
  final bool gameInProgress;
  final bool scoreVisible;
  final bool skillLevelEditable;
  final int skillLevel;
  final int skillLevelMin;
  final int skillLevelMax;
  final double score;
  final void Function(bool? newValue) onScoreVisibleStatusChanged;
  final void Function(double newValue) onSkillLevelChanged;

  const HomePageEvaluationZone({
    super.key,
    required this.gameInProgress,
    required this.scoreVisible,
    required this.skillLevelEditable,
    required this.score,
    required this.skillLevel,
    required this.skillLevelMin,
    required this.skillLevelMax,
    required this.onScoreVisibleStatusChanged,
    required this.onSkillLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx2, constraints) {
      final baseFontSize = constraints.maxWidth * 0.07;
      return Column(
        children: [
          gameInProgress
              ? Row(
                  children: [
                    I18nText(
                      'game.show_evaluation',
                      child: Text(
                        '',
                        style: TextStyle(fontSize: baseFontSize),
                      ),
                    ),
                    Checkbox(
                      value: scoreVisible,
                      onChanged: onScoreVisibleStatusChanged,
                      /* 
                      (newValue) {
                        if (gameInProgress) {
                          setState(() {
                            _scoreVisible = newValue ?? false;
                          });
                          if (scoreVisible) {
                            _startEngineEvaluation();
                          }
                        }
                      },
                      */
                    ),
                  ],
                )
              : const SizedBox(),
          if (scoreVisible)
            Text(
              score.toString(),
              style: TextStyle(
                fontSize: baseFontSize * 0.9,
                color: score < 0
                    ? Colors.red
                    : score > 0
                        ? Colors.green
                        : Colors.black,
              ),
            ),
          if (skillLevelEditable)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                I18nText('game.engine_level'),
                Slider(
                  value: skillLevel.toDouble(),
                  min: skillLevelMin.toDouble(),
                  max: skillLevelMax.toDouble(),
                  onChanged: onSkillLevelChanged,
                  /* (newValue) {
                    setState(() {
                      _skillLevel = newValue.toInt();
                      _stockfish.stdin =
                          'setoption name Skill Level value $_skillLevel';
                    });
                  },
                  */
                ),
                Text(skillLevel.toString()),
              ],
            ),
        ],
      );
    });
  }
}

class HomePageHistoryZone extends StatelessWidget {
  final List<HistoryElement> historyElementsTree;
  final ScrollController scrollController;
  final void Function() onGotoFirstRequest;
  final void Function() onGotoPreviousRequest;
  final void Function() onGotoNextRequest;
  final void Function() onGotoLastRequest;

  const HomePageHistoryZone({
    super.key,
    required this.historyElementsTree,
    required this.scrollController,
    required this.onGotoFirstRequest,
    required this.onGotoPreviousRequest,
    required this.onGotoNextRequest,
    required this.onGotoLastRequest,
  });

  @override
  Widget build(BuildContext context) {
    final historyWidgetsTree = historyElementsTree.map((currentElement) {
      final textComponent = Text(
        currentElement.text,
        style: TextStyle(
          fontSize: currentElement.fontSize,
          fontFamily: 'FreeSerif',
          backgroundColor: currentElement.backgroundColor,
          color: currentElement.textColor,
        ),
      );

      if (currentElement is MoveLinkElement) {
        return TextButton(
          onPressed: currentElement.onPressed,
          child: textComponent,
        );
      } else {
        return textComponent;
      }
    }).toList();

    return Expanded(
      child: ChessHistory(
        scrollController: scrollController,
        requestGotoFirst: onGotoFirstRequest,
        requestGotoPrevious: onGotoPreviousRequest,
        requestGotoNext: onGotoNextRequest,
        requestGotoLast: onGotoLastRequest,
        children: historyWidgetsTree,
      ),
    );
  }
}
