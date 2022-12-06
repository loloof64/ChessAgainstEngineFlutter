import '../../logic/history_builder.dart';

class HistoryManager {
  final void Function() onUpdateChildrenWidgets;
  final void Function({
    required String from,
    required String to,
    required String position,
  }) onPositionSelected;
  final void Function() onSelectStartPosition;
  final bool Function(int) isStartMoveNumber;

  HistoryManager({
    required this.onUpdateChildrenWidgets,
    required this.onPositionSelected,
    required this.onSelectStartPosition,
    required this.isStartMoveNumber,
  });

  HistoryNode? _gameHistoryTree;
  HistoryNode? _currentGameHistoryNode;
  HistoryNode? _selectedHistoryNode;
  List<HistoryElement> _historyElementsTree = [];

  List<HistoryElement> get elementsTree => _historyElementsTree;
  HistoryNode? get currentNode => _currentGameHistoryNode;
  HistoryNode? get gameHistoryTree => _currentGameHistoryNode;
  HistoryNode? get selectedNode => _selectedHistoryNode;

  void newGame(String firstNodeCaption) {
    _selectedHistoryNode = null;
    _gameHistoryTree = HistoryNode(caption: firstNodeCaption);
    _currentGameHistoryNode = _gameHistoryTree;
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
    if (_currentGameHistoryNode != null) {
      /*
      We need to know if it was white move before the move which
      we want to add history node(s).
      */
      if (!isWhiteTurnNow && !isGameStart) {
        final moveNumberCaption = "${position.split(' ')[5]}.";
        final nextHistoryNode = HistoryNode(caption: moveNumberCaption);
        _currentGameHistoryNode?.next = nextHistoryNode;
        _currentGameHistoryNode = nextHistoryNode;
      }

      final nextHistoryNode = HistoryNode(
        caption: lastMoveFan,
        fen: position,
        relatedMove: lastPlayedMove,
      );
      _currentGameHistoryNode?.next = nextHistoryNode;
      _currentGameHistoryNode = nextHistoryNode;
      updateChildrenWidgets();
    }
  }

  void selectCurrentNode() {
    _selectedHistoryNode = _currentGameHistoryNode;
  }

  void addResultString(String resultString) {
    final nextHistoryNode = HistoryNode(caption: resultString);
    _currentGameHistoryNode?.next = nextHistoryNode;
    _currentGameHistoryNode = nextHistoryNode;
    updateChildrenWidgets();
  }

  void gotoFirst() {
    _selectedHistoryNode = null;
  }

  void gotoPrevious() {
    var previousNode = _gameHistoryTree;
    var newSelectedNode = previousNode;
    if (previousNode != null) {
      while (previousNode?.next != _selectedHistoryNode) {
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
        isFirstMoveNumber = isStartMoveNumber(previousMoveNumber);
      }
      if (isFirstMoveNumber) {
        _selectedHistoryNode = null;
        updateChildrenWidgets();
        onSelectStartPosition();
      } else if (newSelectedNode != null &&
          newSelectedNode.relatedMove != null) {
        _selectedHistoryNode = newSelectedNode;
        updateChildrenWidgets();
        onPositionSelected(
          from: newSelectedNode.relatedMove!.from.toString(),
          to: newSelectedNode.relatedMove!.to.toString(),
          position: newSelectedNode.fen!,
        );
      }
    }
  }

  void gotoNext() {
    var nextNode = _selectedHistoryNode != null
        ? _selectedHistoryNode!.next
        : _gameHistoryTree;
    if (nextNode != null) {
      while (nextNode != null && nextNode.relatedMove == null) {
        nextNode = nextNode.next;
      }
      if (nextNode != null && nextNode.relatedMove != null) {
        _selectedHistoryNode = nextNode;
        updateChildrenWidgets();
        onPositionSelected(
          from: nextNode.relatedMove!.from.toString(),
          to: nextNode.relatedMove!.to.toString(),
          position: nextNode.fen!,
        );
      }
    }
  }

  void gotoLast() {
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

    if (newSelectedNode != null && newSelectedNode.relatedMove != null) {
      _selectedHistoryNode = newSelectedNode;
      updateChildrenWidgets();
      onPositionSelected(
        from: newSelectedNode.relatedMove!.from.toString(),
        to: newSelectedNode.relatedMove!.to.toString(),
        position: newSelectedNode.fen!,
      );
    }
  }

  void updateChildrenWidgets() {
    if (_gameHistoryTree != null) {
      _historyElementsTree = recursivelyBuildElementsFromHistoryTree(
          fontSize: 40,
          selectedHistoryNode: _selectedHistoryNode,
          tree: _gameHistoryTree!,
          onHistoryMoveRequested: ({
            required Move historyMove,
            required HistoryNode? selectedHistoryNode,
          }) {
            _selectedHistoryNode = selectedHistoryNode;
            updateChildrenWidgets();
            onPositionSelected(
              from: historyMove.from.toString(),
              to: historyMove.to.toString(),
              position: selectedHistoryNode!.fen!,
            );
          });
      onUpdateChildrenWidgets();
    }
  }
}
