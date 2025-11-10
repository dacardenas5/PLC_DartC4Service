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
