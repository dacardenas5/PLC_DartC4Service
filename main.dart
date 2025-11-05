import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Entry point of the Connect Four application
void main() async {
  Controller().start();
}

/// Controls the game flow
class Controller {
  /// Starts the game and handles turns
  void start() async {
    var ui = ConsoleUI();
    ui.showMessage('Welcome to Connect Four!');

    var url = ui.promptServerUrl(WebClient.defaultUrl);

    ui.showMessage('Retrieving info ...');
    var net = WebClient(url);
    List<String> strategies;

    try {
      strategies = await net.getInfo();
    } catch (e) {
      ui.showMessage('Failed to retrieve info: $e');
      return;
    }

    var selectedStrategy = ui.promptStrategy(strategies);

    String pid;
    try {
      pid = await net.startGame(selectedStrategy);
    } catch (e) {
      ui.showMessage('Failed to start game: $e');
      return;
    }

    var board = Board(width: net.width, height: net.height);
    ui.setBoard(board);

    bool gameOver = false;

    while (!gameOver) {
      ui.showBoard();

      int playerMove;
      try {
        playerMove = ui.promptMove();
      } catch (e) {
        ui.showMessage('Invalid input, please try again.');
        continue;
      }

      try {
        var moveResult = await net.makeMove(pid, playerMove);

        // Drop player token and store last move
        board.dropToken(playerMove, 'o');
        board.lastPlayerCol = playerMove;
        board.lastPlayerRow = board.lastRow;

        // Check if player won
        if (moveResult['ack_move']['isWin'] == true) {
          List<int> flatPositions =
              List<int>.from(moveResult['ack_move']['row']);
          List<List<int>> positions = [];
          for (int i = 0; i < flatPositions.length; i += 2) {
            positions.add([flatPositions[i], flatPositions[i + 1]]);
          }
          board.capitalizeWin(positions);

          ui.showBoard();
          ui.showMessage('You win!');
          gameOver = true;
          break;
        } else if (moveResult['ack_move']['isDraw'] == true) {
          ui.showBoard();
          ui.showMessage('Draw!');
          gameOver = true;
          break;
        }

        // Computer move
        var compMove = moveResult['move'];
        if (compMove != null && compMove['slot'] != null) {
          board.dropToken(compMove['slot'], 'x');
          board.lastComputerCol = compMove['slot'];
          board.lastComputerRow = board.lastRow;

          if (compMove['isWin'] == true) {
            List<int> flatPositions = List<int>.from(compMove['row']);
            List<List<int>> positions = [];
            for (int i = 0; i < flatPositions.length; i += 2) {
              positions.add([flatPositions[i], flatPositions[i + 1]]);
            }
            board.capitalizeWin(positions);

            ui.showBoard();
            ui.showMessage('Computer wins!');
            gameOver = true;
            break;
          } else if (compMove['isDraw'] == true) {
            ui.showBoard();
            ui.showMessage('Draw!');
            gameOver = true;
            break;
          }
        }
      } catch (e) {
        ui.showMessage('Error during move: $e');
        continue;
      }
    }
  }
}

/// Handles HTTP communication with the Connect Four server
class WebClient {
  static const defaultUrl =
      'https://cssrvlab01.utep.edu/Classes/cs3360Cheon/dacardenas5/c4Service/src';
  final String url;
  late int width;
  late int height;

  WebClient([this.url = defaultUrl]);

  /// Gets server info and strategies
  Future<List<String>> getInfo() async {
    var response = await http.get(Uri.parse('$url/info/'));
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}');
    var info = json.decode(response.body);
    width = info['width'];
    height = info['height'];
    return List<String>.from(info['strategies']);
  }

  /// Starts a new game with the selected strategy
  Future<String> startGame(String strategy) async {
    var response = await http.get(Uri.parse('$url/new/?strategy=$strategy'));
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}');
    var data = json.decode(response.body);
    if (data['response'] != true) throw Exception(data['reason']);
    return data['pid'];
  }

  /// Makes a move for the player
  Future<Map<String, dynamic>> makeMove(String pid, int slot) async {
    var response = await http.get(Uri.parse('$url/play/?pid=$pid&move=$slot'));
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}');
    var data = json.decode(response.body);
    if (data['response'] != true) throw Exception(data['reason']);
    return data;
  }
}

/// Handles input/output and displays the board
class ConsoleUI {
  late Board _board;

  /// Sets the board model
  void setBoard(Board board) => _board = board;

  /// Prints a message to the console
  void showMessage(String msg) => print(msg);

  /// Prompts the user for server URL
  String promptServerUrl(String defaultUrl) {
    stdout.write('Enter the C4 server URL [default=$defaultUrl]: ');
    var url = stdin.readLineSync();
    if (url == null || url.trim().isEmpty) url = defaultUrl;
    return url;
  }

  /// Prompts the user to select a strategy
  String promptStrategy(List<String> strategies) {
    for (var i = 0; i < strategies.length; i++)
      print('${i + 1}. ${strategies[i]}');
    stdout.write('Enter choice [1-${strategies.length}]: ');
    var input = stdin.readLineSync();
    int choice = 1;
    if (input != null && int.tryParse(input) != null) {
      choice = int.parse(input);
      if (choice < 1 || choice > strategies.length) choice = 1;
    }
    return strategies[choice - 1];
  }

  /// Prompts the user to select a valid move
  int promptMove() {
    while (true) {
      stdout.write('Select a slot [1-${_board.width}]: ');
      var line = stdin.readLineSync()!.trim();
      try {
        var response = int.parse(line);
        if (response >= 1 &&
            response <= _board.width &&
            !_board.isSlotFull(response - 1)) {
          return response - 1;
        }
      } on FormatException {}
      print('Invalid selection: $line');
    }
  }

  /// Displays the board with last moves and winning positions
  void showBoard() {
    print('');
    for (int r = 0; r < _board.height; r++) {
      var line = '| ';
      for (int c = 0; c < _board.width; c++) {
        line += '${tokenSymbol(c, r)} | ';
      }
      print(line);
    }
    print(List.generate(_board.width, (i) => ' ${i + 1} ').join(' '));
    print('');
  }

  /// Returns the symbol for a token, capitalizing last moves and winning positions
  String tokenSymbol(int col, int row) {
    String t = _board.rows[col][row];
    if (t == ' ') return ' ';

    if ((col == _board.lastPlayerCol && row == _board.lastPlayerRow) ||
        (col == _board.lastComputerCol && row == _board.lastComputerRow)) {
      return t.toUpperCase();
    }

    for (var pos in _board.winningPositions) {
      if (pos[0] == col && pos[1] == row) return t.toUpperCase();
    }

    return t;
  }
}

/// Represents a Connect Four board
class Board {
  final int width;
  final int height;
  late List<List<String>> _rows;

  int? lastCol;
  int? lastRow;

  int? lastPlayerCol;
  int? lastPlayerRow;

  int? lastComputerCol;
  int? lastComputerRow;

  List<List<int>> winningPositions = [];

  Board({this.width = 7, this.height = 6}) {
    _rows = List.generate(width, (_) => List.filled(height, ' '));
  }

  List<List<String>> get rows => _rows;

  bool isSlotFull(int col) => _rows[col][0] != ' ';

  /// Drops a token in a column
  void dropToken(int col, String token) {
    for (int r = height - 1; r >= 0; r--) {
      if (_rows[col][r] == ' ') {
        _rows[col][r] = token.toLowerCase();
        lastCol = col;
        lastRow = r;
        return;
      }
    }
    throw Exception('Invalid slot, $col');
  }

  /// Capitalizes winning tokens
  void capitalizeWin(List<List<int>> positions) {
    winningPositions = positions;
  }
}
