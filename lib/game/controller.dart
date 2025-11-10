import '../ui/console_ui.dart';
import '../web/web_client.dart';
import 'board.dart';

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
