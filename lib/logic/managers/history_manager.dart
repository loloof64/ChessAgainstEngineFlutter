import 'package:chess_against_engine/logic/managers/game_manager.dart';
import 'package:flutter/material.dart';

import '../../logic/history_builder.dart';

class HistoryState {
  final HistoryNode? gameHistoryTree;
  final HistoryNode? currentGameHistoryNode;
  final HistoryNode? selectedHistoryNode;
  final List<HistoryElement> historyElementsTree;

  HistoryState({
    this.gameHistoryTree,
    this.currentGameHistoryNode,
    this.selectedHistoryNode,
    required this.historyElementsTree,
  });

  HistoryState copyWith({
    HistoryNode? gameHistoryTree,
    HistoryNode? currentGameHistoryNode,
    HistoryNode? selectedHistoryNode,
    List<HistoryElement>? historyElementsTree,
  }) {
    return HistoryState(
      gameHistoryTree: gameHistoryTree ?? this.gameHistoryTree,
      currentGameHistoryNode:
          currentGameHistoryNode ?? this.currentGameHistoryNode,
      selectedHistoryNode: selectedHistoryNode ?? this.selectedHistoryNode,
      historyElementsTree: historyElementsTree ?? this.historyElementsTree,
    );
  }
}

typedef UpdateChildrenWidgetsCallback = void Function();
typedef PositionSelectedCallback = void Function({
  required String from,
  required String to,
  required String position,
});
typedef StartPositionSelectedCallback = void Function();

class HistoryManager extends ValueNotifier<HistoryState> {
  final List<UpdateChildrenWidgetsCallback> _updateChildrenCallbacks = [];
  final List<PositionSelectedCallback> _positionSelectedCallbacks = [];
  final List<StartPositionSelectedCallback> _startPositionSelectedCallbacks =
      [];

  HistoryManager._sharedInstance()
      : super(
          HistoryState(
            historyElementsTree: [],
          ),
        );
  static final HistoryManager _shared = HistoryManager._sharedInstance();

  factory HistoryManager() => _shared;

  void addUpdateChildrenWidgetsCallback(
      UpdateChildrenWidgetsCallback callback) {
    _updateChildrenCallbacks.add(callback);
  }

  void addPositionSelectedCallback(PositionSelectedCallback callback) {
    _positionSelectedCallbacks.add(callback);
  }

  void addStartPositionSelectedCallback(
      StartPositionSelectedCallback callback) {
    _startPositionSelectedCallbacks.add(callback);
  }

  void removeUpdateChildrenWidgetsCallback(
      UpdateChildrenWidgetsCallback callback) {
    _updateChildrenCallbacks.remove(callback);
  }

  void removePositionSelectedCallback(PositionSelectedCallback callback) {
    _positionSelectedCallbacks.remove(callback);
  }

  void removeStartPositionSelectedCallback(
      StartPositionSelectedCallback callback) {
    _startPositionSelectedCallbacks.remove(callback);
  }

  List<HistoryElement> get elementsTree => value.historyElementsTree;
  HistoryNode? get currentNode => value.currentGameHistoryNode;
  HistoryNode? get gameHistoryTree => value.currentGameHistoryNode;
  HistoryNode? get selectedNode => value.selectedHistoryNode;

  void newGame(String firstNodeCaption) {
    final commonStartNode = HistoryNode(caption: firstNodeCaption);
    value = value.copyWith(
      selectedHistoryNode: null,
      gameHistoryTree: commonStartNode,
      currentGameHistoryNode: commonStartNode,
    );
    updateChildrenWidgets();
  }

  /*
    Must be called after a move has just been
    added to _gameLogic.
  */
  void addMove({
    required bool isWhiteTurnNow,
    required bool isGameStart,
    required String lastMoveFan,
    required String position,
    required Move lastPlayedMove,
  }) {
    if (value.currentGameHistoryNode != null) {
      /*
      We need to know if it was white move before the move which
      we want to add history node(s).
      */
      if (!isWhiteTurnNow && !isGameStart) {
        final moveNumberCaption = "${position.split(' ')[5]}.";
        final nextHistoryNode = HistoryNode(caption: moveNumberCaption);
        value.currentGameHistoryNode?.next = nextHistoryNode;
        value = value.copyWith(currentGameHistoryNode: nextHistoryNode);
      }

      final nextHistoryNode = HistoryNode(
        caption: lastMoveFan,
        fen: position,
        relatedMove: lastPlayedMove,
      );
      value.currentGameHistoryNode?.next = nextHistoryNode;
      value = value.copyWith(currentGameHistoryNode: nextHistoryNode);
      updateChildrenWidgets();
    }
  }

  void selectCurrentNode() {
    value = value.copyWith(selectedHistoryNode: value.currentGameHistoryNode);
    notifyListeners();
  }

  void addResultString(String resultString) {
    final nextHistoryNode = HistoryNode(caption: resultString);
    value.currentGameHistoryNode?.next = nextHistoryNode;
    value = value.copyWith(currentGameHistoryNode: nextHistoryNode);
    updateChildrenWidgets();
  }

  void gotoFirst() {
    value = value.copyWith(selectedHistoryNode: null);
    notifyListeners();
  }

  void gotoPrevious() {
    if (value.selectedHistoryNode == null) {
      return;
    }
    var previousNode = value.gameHistoryTree;
    var newSelectedNode = previousNode;
    if (previousNode != null) {
      while (previousNode?.next != value.selectedHistoryNode) {
        previousNode = previousNode?.next != null
            ? HistoryNode.from(previousNode!.next!)
            : null;
        if (previousNode?.relatedMove != null) newSelectedNode = previousNode;
      }
      bool isFirstMoveNumber;
      if (previousNode?.fen != null) {
        isFirstMoveNumber = false;
      } else {
        final previousCaption = previousNode!.caption;
        final previousCaptionPointIndex = previousCaption
            .split('')
            .asMap()
            .entries
            .firstWhere((e) => e.value == '.')
            .key;
        final previousMoveNumber =
            int.parse(previousCaption.substring(0, previousCaptionPointIndex));
        isFirstMoveNumber = _isStartMoveNumber(previousMoveNumber);
      }
      if (isFirstMoveNumber) {
        value = value.copyWith(selectedHistoryNode: null);
        updateChildrenWidgets();
        for (StartPositionSelectedCallback callback
            in _startPositionSelectedCallbacks) {
          callback();
        }
      } else if (newSelectedNode != null &&
          newSelectedNode.relatedMove != null) {
        value = value.copyWith(selectedHistoryNode: newSelectedNode);
        updateChildrenWidgets();
        for (PositionSelectedCallback callback in _positionSelectedCallbacks) {
          callback(
            from: newSelectedNode.relatedMove!.from.toString(),
            to: newSelectedNode.relatedMove!.to.toString(),
            position: newSelectedNode.fen!,
          );
        }
      }
    }
  }

  void gotoNext() {
    var nextNode = value.selectedHistoryNode != null
        ? value.selectedHistoryNode!.next
        : value.gameHistoryTree;
    if (nextNode != null) {
      while (nextNode != null && nextNode.relatedMove == null) {
        nextNode = nextNode.next;
      }
      if (nextNode != null && nextNode.relatedMove != null) {
        value = value.copyWith(selectedHistoryNode: nextNode);
        updateChildrenWidgets();
        for (PositionSelectedCallback callback in _positionSelectedCallbacks) {
          callback(
            from: nextNode.relatedMove!.from.toString(),
            to: nextNode.relatedMove!.to.toString(),
            position: nextNode.fen!,
          );
        }
      }
    }
  }

  void gotoLast() {
    var nextNode = value.selectedHistoryNode != null
        ? value.selectedHistoryNode!.next
        : value.gameHistoryTree;
    var newSelectedNode = nextNode;

    while (true) {
      nextNode =
          nextNode?.next != null ? HistoryNode.from(nextNode!.next!) : null;
      if (nextNode == null) break;
      if (nextNode.fen != null) {
        newSelectedNode = nextNode;
      }
    }

    if (newSelectedNode != null && newSelectedNode.relatedMove != null) {
      value = value.copyWith(selectedHistoryNode: newSelectedNode);
      updateChildrenWidgets();
      for (PositionSelectedCallback callback in _positionSelectedCallbacks) {
        callback(
          from: newSelectedNode.relatedMove!.from.toString(),
          to: newSelectedNode.relatedMove!.to.toString(),
          position: newSelectedNode.fen!,
        );
      }
    }
  }

  void updateChildrenWidgets() {
    if (value.gameHistoryTree != null) {
      value = value.copyWith(
        historyElementsTree: recursivelyBuildElementsFromHistoryTree(
            fontSize: 40,
            selectedHistoryNode: value.selectedHistoryNode,
            tree: value.gameHistoryTree!,
            onHistoryMoveRequested: ({
              required Move historyMove,
              required HistoryNode? selectedHistoryNode,
            }) {
              value = value.copyWith(selectedHistoryNode: selectedHistoryNode);
              updateChildrenWidgets();
              for (PositionSelectedCallback callback
                  in _positionSelectedCallbacks) {
                callback(
                  from: historyMove.from.toString(),
                  to: historyMove.to.toString(),
                  position: selectedHistoryNode!.fen!,
                );
              }
            }),
      );
      for (UpdateChildrenWidgetsCallback callback in _updateChildrenCallbacks) {
        callback();
      }
    }
  }

  bool _isStartMoveNumber(int moveNumber) {
    return int.parse(GameManager().currentState.startPosition.split(' ')[5]) ==
        moveNumber;
  }
}
