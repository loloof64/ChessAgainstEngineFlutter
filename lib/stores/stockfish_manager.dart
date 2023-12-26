import 'package:mobx/mobx.dart';
import 'package:chess_against_engine/logic/managers/stockfish_manager.dart';

part 'stockfish_manager.g.dart';

class StockfishManagerStore = StockfishManagerBase with _$StockfishManagerStore;

abstract class StockfishManagerBase with Store {
  @observable
  StockfishManager? manager;

  @action
  setManager(StockfishManager manager) {
    this.manager = manager;
  }
}