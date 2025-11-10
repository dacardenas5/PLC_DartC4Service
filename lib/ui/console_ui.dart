import '../game/board.dart';
import 'dart:io';

/// Handles console input/output and board display
class ConsoleUI {
  late Board _board; // reference to board model

  void setBoard(Board board) => _board = board; // attach board

  void showMessage(String msg) => print(msg); // print message

  String promptServerUrl(String defaultUrl) {
    stdout.write('Enter the C4 server URL [default=$defaultUrl]: '); // ask URL
    var url = stdin.readLineSync();
    if (url == null || url.trim().isEmpty) url = defaultUrl; // default if empty
    return url;
  }

  String promptStrategy(List<String> strategies) {
    for (var i = 0; i < strategies.length; i++)
      print('${i + 1}. ${strategies[i]}'); // print options
    stdout.write('Enter choice [1-${strategies.length}]: ');
    var input = stdin.readLineSync();
    int choice = 1;
    if (input != null && int.tryParse(input) != null) {
      choice = int.parse(input);
      if (choice < 1 || choice > strategies.length) choice = 1; // bounds check
    }
    return strategies[choice - 1]; // return chosen strategy
  }

  int promptMove() {
    while (true) {
      stdout.write('Select a slot [1-${_board.width}]: '); // ask move
      var line = stdin.readLineSync()!.trim();
      try {
        var response = int.parse(line);
        if (response >= 1 &&
            response <= _board.width &&
            !_board.isSlotFull(response - 1)) {
          return response - 1; // valid move
        }
      } on FormatException {}
      print('Invalid selection: $line'); // invalid input
    }
  }

  void showBoard() {
    print('');
    for (int r = 0; r < _board.height; r++) {
      var line = '| ';
      for (int c = 0; c < _board.width; c++) {
        line += '${tokenSymbol(c, r)} | '; // display token
      }
      print(line);
    }
    print(List.generate(_board.width, (i) => ' ${i + 1} ')
        .join(' ')); // column numbers
    print('');
  }

  String tokenSymbol(int col, int row) {
    String t = _board.rows[col][row]; // get token
    if (t == ' ') return ' '; // empty

    // highlight last moves
    if ((col == _board.lastPlayerCol && row == _board.lastPlayerRow) ||
        (col == _board.lastComputerCol && row == _board.lastComputerRow)) {
      return t.toUpperCase();
    }

    // highlight winning tokens
    for (var pos in _board.winningPositions) {
      if (pos[0] == col && pos[1] == row) return t.toUpperCase();
    }

    return t; // normal token
  }
}
