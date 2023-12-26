// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stockfish_manager.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StockfishManagerStore on StockfishManagerBase, Store {
  late final _$managerAtom =
      Atom(name: 'StockfishManagerBase.manager', context: context);

  @override
  StockfishManager? get manager {
    _$managerAtom.reportRead();
    return super.manager;
  }

  @override
  set manager(StockfishManager? value) {
    _$managerAtom.reportWrite(value, super.manager, () {
      super.manager = value;
    });
  }

  late final _$StockfishManagerBaseActionController =
      ActionController(name: 'StockfishManagerBase', context: context);

  @override
  dynamic setManager(StockfishManager manager) {
    final _$actionInfo = _$StockfishManagerBaseActionController.startAction(
        name: 'StockfishManagerBase.setManager');
    try {
      return super.setManager(manager);
    } finally {
      _$StockfishManagerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
manager: ${manager}
    ''';
  }
}
