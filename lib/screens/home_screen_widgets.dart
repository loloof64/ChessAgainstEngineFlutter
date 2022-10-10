import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:simple_chess_board/simple_chess_board.dart';
import 'package:simple_chess_board/models/board_arrow.dart';
import '../logic/history/history_builder.dart';
import '../components/history.dart';

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
