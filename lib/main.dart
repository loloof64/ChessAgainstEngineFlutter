import 'package:flutter/material.dart';
import 'package:simple_chess_board/models/board_arrow.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';
import '../components/dialog_buttons.dart';
import '../components/history.dart';
import '../logic/history/history_builder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => FlutterI18n.translate(context, 'app.title'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
      localizationsDelegates: [
        FlutterI18nDelegate(
          translationLoader: FileTranslationLoader(
            basePath: 'assets/i18n',
            useCountryCode: false,
            fallbackFile: 'en',
            decodeStrategies: [YamlDecodeStrategy()],
          ),
          missingTranslationHandler: (key, locale) {
            Logger().w(
                "--- Missing Key: $key, languageCode: ${locale?.languageCode}");
          },
        ),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
        Locale('es', ''),
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bishop.Game _gameLogic = bishop.Game(
      variant: bishop.Variant.standard(), fen: '8/8/8/8/8/8/8/8 w - - 0 1');
  BoardColor _orientation = BoardColor.white;
  PlayerType _whitePlayerType = PlayerType.computer;
  PlayerType _blackPlayerType = PlayerType.computer;
  HistoryNode? _gameHistoryTree;
  HistoryNode? _currentGameHistoryNode;
  HistoryNode? _selectedHistoryNode;
  List<Widget> _historyWidgetsTree = [];
  static const defaultPosition =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  final _startPosition = defaultPosition;
  bool _gameStart = false;
  bool _gameInProgress = false;
  BoardArrow? _lastMoveArrow;

  /*
    Must be called after a move has just been
    added to _gameLogic
    Do not update state itself.
  */
  void _addMoveToHistory() {
    if (_currentGameHistoryNode != null) {
      final whiteMove = _gameLogic.turn == bishop.WHITE;
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

      final san = _gameLogic.sanMoves().last;

      // Move has been played: we need to revert player turn for the SAN.
      final fan = san.toFan(whiteMove: !whiteMove);
      final relatedMoveFromSquareIndex =
          CellIndexConverter(lastPlayedMove!.from)
              .convertSquareIndexFromBishop();
      final relatedMoveToSquareIndex =
          CellIndexConverter(lastPlayedMove.to).convertSquareIndexFromBishop();

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
    if (_gameLogic.checkmate) {
      return _gameLogic.turn == bishop.WHITE ? '0-1' : '1-0';
    }
    if (_gameLogic.inDraw) {
      return '1/2-1/2';
    }
    return '*';
  }

  Widget _getGameEndedType() {
    dynamic result;
    if (_gameLogic.checkmate) {
      result = (_gameLogic.turn == bishop.WHITE)
          ? I18nText('game_termination.black_checkmate_white')
          : I18nText('game_termination.white_checkmate_black');
    } else if (_gameLogic.stalemate) {
      result = I18nText('game_termination.stalemate');
    } else if (_gameLogic.repetition) {
      result = I18nText('game_termination.repetitions');
    } else if (_gameLogic.insufficientMaterial) {
      result = I18nText('game_termination.insufficient_material');
    } else if (_gameLogic.inDraw) {
      result = I18nText('game_termination.fifty_moves');
    }
    return result;
  }

  void _tryMakingMove({required ShortMove move}) {
    final moveAlgebraic =
        "${move.from}${move.to}${move.promotion.map((t) => t.name).getOrElse(() => '')}";
    final matchingMove = _gameLogic.getMove(moveAlgebraic);
    if (matchingMove != null) {
      setState(() {
        _gameLogic.makeMove(matchingMove);
        _addMoveToHistory();
        _gameStart = false;
      });
      if (_gameLogic.gameOver) {
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
    }
  }

  void _startNewGame() {
    setState(() {
      _whitePlayerType = PlayerType.human;
      _blackPlayerType = PlayerType.human;
      _gameStart = true;
      _gameInProgress = true;
      _gameLogic =
          bishop.Game(variant: bishop.Variant.standard(), fen: _startPosition);
      final startPosition = _startPosition;
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
        _historyWidgetsTree = recursivelyBuildWidgetsFromHistoryTree(
          fontSize: 40,
          selectedHistoryNode: _selectedHistoryNode,
          tree: _gameHistoryTree!,
          onMoveDoneUpdateRequest: onMoveDoneUpdateRequest,
        );
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
      _lastMoveArrow = BoardArrow(
        from: _currentGameHistoryNode!.relatedMove!.from.toString(),
        to: _currentGameHistoryNode!.relatedMove!.to.toString(),
        color: Colors.blueAccent,
      );
      _selectedHistoryNode = _currentGameHistoryNode;
      _currentGameHistoryNode?.next = nextHistoryNode;
      _currentGameHistoryNode = nextHistoryNode;
      _gameInProgress = false;
      _whitePlayerType = PlayerType.computer;
      _blackPlayerType = PlayerType.computer;
    });
    _updateHistoryChildrenWidgets();
    /*
    setState(() {
      _engineThinking = false;
    });
    */
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [I18nText('game.stopped')],
        ),
      ),
    );
  }

  void onMoveDoneUpdateRequest({required Move moveDone}) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: I18nText('app.title'),
        actions: [
          IconButton(
            onPressed: _startNewGame,
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
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 600,
                child: SimpleChessBoard(
                    lastMoveToHighlight: _lastMoveArrow,
                    fen: _gameLogic.fen,
                    orientation: _orientation,
                    whitePlayerType: _whitePlayerType,
                    blackPlayerType: _blackPlayerType,
                    onMove: _tryMakingMove,
                    onPromote: _handlePromotion),
              ),
              const SizedBox(
                width: 30,
              ),
              ChessHistory(
                historyTree: _gameHistoryTree,
                children: _historyWidgetsTree,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
