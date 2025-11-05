import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Entry point of the Connect Four application
void main() async {
  Controller().start(); // start the game
}

/// Controls the game flow, handling turns, moves, and game end conditions
class Controller {
  /// Starts the game and manages the sequence of player and computer moves
  void start() async {
    var ui = ConsoleUI();
    ui.showMessage('Welcome to Connect Four!'); // welcome message

    var url =
        ui.promptServerUrl(WebClient.defaultUrl); // ask user for server URL

    ui.showMessage('Retrieving info ...');
    var net = WebClient(url);
    List<String> strategies;

    try {
      strategies = await net.getInfo(); // get strategies from server
    } catch (e) {
      ui.showMessage('Failed to retrieve info: $e'); // network error
      return;
    }

    var selectedStrategy = ui.promptStrategy(strategies); // choose strategy

    String pid;
    try {
      pid = await net.startGame(selectedStrategy); // start game on server
    } catch (e) {
      ui.showMessage('Failed to start game: $e'); // server error
      return;
    }

    var board =
        Board(width: net.width, height: net.height); // create board model
    ui.setBoard(board); // attach board to UI

    bool gameOver = false;

    while (!gameOver) {
      ui.showBoard(); // show current board

      int playerMove;
      try {
        playerMove = ui.promptMove(); // get player move
      } catch (e) {
        ui.showMessage('Invalid input, please try again.'); // invalid input
        continue;
      }

      try {
        var moveResult =
            await net.makeMove(pid, playerMove); // send move to server

        // Drop player token locally
        board.dropToken(playerMove, 'o'); // 'o' for player
        board.lastPlayerCol = playerMove; // track last player move
        board.lastPlayerRow = board.lastRow;

        // Check if player won
        if (moveResult['ack_move']['isWin'] == true) {
          // convert flat array to coordinate pairs
          List<int> flatPositions =
              List<int>.from(moveResult['ack_move']['row']);
          List<List<int>> positions = [];
          for (int i = 0; i < flatPositions.length; i += 2) {
            positions.add([flatPositions[i], flatPositions[i + 1]]);
          }
          board.capitalizeWin(positions); // highlight winning positions

          ui.showBoard();
          ui.showMessage('You win!'); // player won
          gameOver = true;
          break;
        } else if (moveResult['ack_move']['isDraw'] == true) {
          ui.showBoard();
          ui.showMessage('Draw!'); // game draw
          gameOver = true;
          break;
        }

        // Computer move from server response
        var compMove = moveResult['move'];
        if (compMove != null && compMove['slot'] != null) {
          board.dropToken(compMove['slot'], 'x'); // 'x' for computer
          board.lastComputerCol = compMove['slot']; // track last computer move
          board.lastComputerRow = board.lastRow;

          // Check if computer won
          if (compMove['isWin'] == true) {
            List<int> flatPositions = List<int>.from(compMove['row']);
            List<List<int>> positions = [];
            for (int i = 0; i < flatPositions.length; i += 2) {
              positions.add([flatPositions[i], flatPositions[i + 1]]);
            }
            board.capitalizeWin(positions); // highlight computer win

            ui.showBoard();
            ui.showMessage('Computer wins!'); // computer won
            gameOver = true;
            break;
          } else if (compMove['isDraw'] == true) {
            ui.showBoard();
            ui.showMessage('Draw!'); // draw detected
            gameOver = true;
            break;
          }
        }
      } catch (e) {
        ui.showMessage('Error during move: $e'); // catch all other errors
        continue;
      }
    }
  }
}

/// Handles HTTP communication with the Connect Four server
class WebClient {
  static const defaultUrl =
      'https://cssrvlab01.utep.edu/Classes/cs3360Cheon/dacardenas5/c4Service/src'; // default URL

  final String url;
  late int width;
  late int height;

  WebClient([this.url = defaultUrl]); // constructor

  /// Gets server info and returns available strategies
  Future<List<String>> getInfo() async {
    var response = await http.get(Uri.parse('$url/info/')); // GET /info
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}'); // error handling
    var info = json.decode(response.body);
    width = info['width']; // store board width
    height = info['height']; // store board height
    return List<String>.from(info['strategies']); // return strategies
  }

  /// Starts a new game with the selected strategy
  Future<String> startGame(String strategy) async {
    var response =
        await http.get(Uri.parse('$url/new/?strategy=$strategy')); // GET /new
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}'); // error handling
    var data = json.decode(response.body);
    if (data['response'] != true)
      throw Exception(data['reason']); // server reject
    return data['pid']; // return game PID
  }

  /// Makes a move for the player and returns server response
  Future<Map<String, dynamic>> makeMove(String pid, int slot) async {
    var response = await http
        .get(Uri.parse('$url/play/?pid=$pid&move=$slot')); // GET /play
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}'); // network error
    var data = json.decode(response.body);
    if (data['response'] != true)
      throw Exception(data['reason']); // invalid move
    return data; // return move result
  }
}

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

/// Represents the Connect Four board state
class Board {
  final int width; // board width
  final int height; // board height
  late List<List<String>> _rows; // board array

  int? lastCol; // last move column
  int? lastRow; // last move row

  int? lastPlayerCol; // last player move column
  int? lastPlayerRow; // last player move row

  int? lastComputerCol; // last computer move column
  int? lastComputerRow; // last computer move row

  List<List<int>> winningPositions = []; // winning coordinates

  Board({this.width = 7, this.height = 6}) {
    _rows =
        List.generate(width, (_) => List.filled(height, ' ')); // empty board
  }

  List<List<String>> get rows => _rows;

  bool isSlotFull(int col) => _rows[col][0] != ' '; // check if column full

  void dropToken(int col, String token) {
    for (int r = height - 1; r >= 0; r--) {
      // drop from bottom
      if (_rows[col][r] == ' ') {
        _rows[col][r] = token.toLowerCase(); // add token
        lastCol = col;
        lastRow = r; // store last move
        return;
      }
    }
    throw Exception('Invalid slot, $col'); // column full
  }

  void capitalizeWin(List<List<int>> positions) {
    winningPositions = positions; // mark winning tokens
  }
}
