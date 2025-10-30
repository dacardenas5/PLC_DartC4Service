import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Entry point of the Connect Four application.
void main() async {
  Controller().start();
}

/// Controller class for managing game flow.
class Controller {
  /// Starts the Connect Four game.
  void start() async {
    var ui = ConsoleUI();
    ui.showMessage('Welcome to Connect Four!');

    // Ask for server URL
    var url = ui.promptServerUrl(WebClient.defaultUrl);

    // Retrieve info from server
    ui.showMessage('Retrieving info ...');
    var net = WebClient(url);
    List<String> strategies;
    try {
      strategies = await net.getInfo();
    } catch (e) {
      ui.showMessage('Failed to retrieve info: $e');
      return;
    }

    // Prompt user to select strategy
    var selectedStrategy = ui.promptStrategy(strategies);

    // Start game on server
    String pid;
    try {
      pid = await net.startGame(selectedStrategy);
    } catch (e) {
      ui.showMessage('Failed to start game: $e');
      return;
    }

    // Initialize board locally
    var board = Board(width: net.width, height: net.height);
    ui.setBoard(board);

    // Game loop
    bool gameOver = false;
    while (!gameOver) {
      ui.showBoard();
      int playerMove = ui.promptMove();

      try {
        var moveResult = await net.makeMove(pid, playerMove);

        // Apply player move locally
        board.dropToken(playerMove, 'P');

        // Check player win/draw
        if (board.checkWin('P')) {
          ui.showBoard(highlight: board.winningSequence);
          ui.showMessage('You win!');
          gameOver = true;
          break;
        } else if (moveResult['ack_move']['isDraw'] == true) {
          ui.showBoard();
          ui.showMessage('Draw!');
          gameOver = true;
          break;
        }

        // Apply computer move locally
        var compMove = moveResult['move'];
        if (compMove != null && compMove['slot'] != null) {
          board.dropToken(compMove['slot'], 'C');

          if (board.checkWin('C')) {
            ui.showBoard(highlight: board.winningSequence);
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
        return;
      }
    }
  }
}

/// Handles HTTP communication with the Connect Four server.
class WebClient {
  static const defaultUrl =
      'https://cssrvlab01.utep.edu/Classes/cs3360Cheon/dacardenas5/c4Service/src';
  final String url;
  late int width;
  late int height;

  WebClient([this.url = defaultUrl]);

  /// Retrieves board size and available strategies from the server.
  Future<List<String>> getInfo() async {
    var response = await http.get(Uri.parse('$url/info/'));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    var info = json.decode(response.body);
    width = info['width'];
    height = info['height'];
    return List<String>.from(info['strategies']);
  }

  /// Starts a new game with the selected strategy.
  Future<String> startGame(String strategy) async {
    var response = await http.get(Uri.parse('$url/new/?strategy=$strategy'));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    var data = json.decode(response.body);
    if (data['response'] != true) {
      throw Exception(data['reason']);
    }
    return data['pid'];
  }

  /// Sends a move to the server and returns the result.
  Future<Map<String, dynamic>> makeMove(String pid, int slot) async {
    var response = await http.get(Uri.parse('$url/play/?pid=$pid&move=$slot'));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    var data = json.decode(response.body);
    if (data['response'] != true) {
      throw Exception(data['reason']);
    }
    return data;
  }
}

/// Handles input/output and displays the board.
class ConsoleUI {
  late Board _board;

  /// Sets the board model to be used for display.
  void setBoard(Board board) {
    _board = board;
  }

  /// Displays a message to the user.
  void showMessage(String msg) {
    print(msg);
  }

  /// Prompts the user for the Connect Four server URL.
  String promptServerUrl(String defaultUrl) {
    stdout.write('Enter the C4 server URL [default=$defaultUrl]: ');
    var url = stdin.readLineSync();
    if (url == null || url.trim().isEmpty) {
      url = defaultUrl;
    }
    return url;
  }

  /// Prompts the user to select a strategy from the available options.
  String promptStrategy(List<String> strategies) {
    for (var i = 0; i < strategies.length; i++) {
      print('${i + 1}. ${strategies[i]}');
    }
    stdout.write('Enter choice [1-${strategies.length}]: ');
    var input = stdin.readLineSync();
    int choice = 1;
    if (input != null && int.tryParse(input) != null) {
      choice = int.parse(input);
      if (choice < 1 || choice > strategies.length) choice = 1;
    }
    return strategies[choice - 1];
  }

  /// Prompts the player to select a valid slot.
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

  /// Displays the current board, optionally highlighting a winning sequence.
  void showBoard({List<Point>? highlight}) {
    for (int r = 0; r < _board.height; r++) {
      var line = '';
      for (int c = 0; c < _board.width; c++) {
        bool isHighlight =
            highlight != null && highlight.any((p) => p.x == c && p.y == r);
        line += isHighlight
            ? '*${tokenSymbol(_board.rows[c][r])}* '
            : '${tokenSymbol(_board.rows[c][r])} ';
      }
      print(line.trim());
    }
    print(List.generate(_board.width, (i) => i + 1).join(' '));
    print('');
  }

  /// Returns the display symbol for a token.
  String tokenSymbol(String t) {
    switch (t) {
      case 'P':
        return 'O'; // player
      case 'C':
        return 'X'; // computer
      default:
        return '.'; // empty
    }
  }
}

/// Represents a Connect Four board.
class Board {
  final int width;
  final int height;
  late List<List<String>> _rows;

  /// Stores the last detected winning sequence (used for highlighting).
  List<Point> winningSequence = [];

  Board({this.width = 7, this.height = 6}) {
    _rows = List.generate(width, (_) => List.filled(height, ' '));
  }

  /// Returns the board rows.
  List<List<String>> get rows => _rows;

  /// Checks if a column is full.
  bool isSlotFull(int col) {
    return _rows[col][0] != ' ';
  }

  /// Drops a token into a column.
  void dropToken(int col, String token) {
    for (int r = height - 1; r >= 0; r--) {
      if (_rows[col][r] == ' ') {
        _rows[col][r] = token;
        return;
      }
    }
    throw Exception('Invalid slot, $col');
  }

  /// Checks if a given token has a winning sequence on the board.
  bool checkWin(String token) {
    winningSequence.clear();

    // Horizontal
    for (int r = 0; r < height; r++) {
      for (int c = 0; c <= width - 4; c++) {
        if (List.generate(4, (i) => _rows[c + i][r]).every((t) => t == token)) {
          winningSequence = List.generate(4, (i) => Point(c + i, r));
          return true;
        }
      }
    }

    // Vertical
    for (int c = 0; c < width; c++) {
      for (int r = 0; r <= height - 4; r++) {
        if (List.generate(4, (i) => _rows[c][r + i]).every((t) => t == token)) {
          winningSequence = List.generate(4, (i) => Point(c, r + i));
          return true;
        }
      }
    }

    // Diagonal down-right
    for (int c = 0; c <= width - 4; c++) {
      for (int r = 0; r <= height - 4; r++) {
        if (List.generate(4, (i) => _rows[c + i][r + i])
            .every((t) => t == token)) {
          winningSequence = List.generate(4, (i) => Point(c + i, r + i));
          return true;
        }
      }
    }

    // Diagonal up-right
    for (int c = 0; c <= width - 4; c++) {
      for (int r = 3; r < height; r++) {
        if (List.generate(4, (i) => _rows[c + i][r - i])
            .every((t) => t == token)) {
          winningSequence = List.generate(4, (i) => Point(c + i, r - i));
          return true;
        }
      }
    }

    return false;
  }
}

/// Simple 2D point for board coordinates.
class Point {
  final int x;
  final int y;

  Point(this.x, this.y);
}
