import 'package:flutter/material.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';

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

  void _tryMakingMove({required ShortMove move}) {
    final moveAlgebraic =
        "${move.from}${move.to}${move.promotion.map((t) => t.name).getOrElse(() => '')}";
    final matchingMove = _gameLogic.getMove(moveAlgebraic);
    if (matchingMove != null) {
      setState(() {
        _gameLogic.makeMove(matchingMove);
      });
    }
  }

  void _startNewGame() {
    setState(() {
      _whitePlayerType = PlayerType.human;
      _blackPlayerType = PlayerType.human;
      _gameLogic = bishop.Game(variant: bishop.Variant.standard());
    });
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
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              height: 600,
              child: SimpleChessBoard(
                  fen: _gameLogic.fen,
                  orientation: _orientation,
                  whitePlayerType: _whitePlayerType,
                  blackPlayerType: _blackPlayerType,
                  onMove: _tryMakingMove,
                  onPromote: _handlePromotion),
            ),
          ],
        ),
      ),
    );
  }
}
