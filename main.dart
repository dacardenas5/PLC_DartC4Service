import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  Controller().start();
}

class Controller {
  void start() async {
    var ui = ConsoleUI();
    ui.showMessage('Welcome to C4!');

    var url = ui.promptServerUrl(WebClient.defaultUrl);

    ui.showMessage('Retrieving info ...');
    var net = WebClient(url);
    var strategies = await net.getInfo();

    var selectedStrategy = ui.promptStrategy(strategies);

    // TODO: Continue with game loop, drop tokens, etc.
  }
}

class WebClient {
  static const defaultUrl = 'https://www.cs.utep.edu/cheon/cs3360/project/c4/';
  final String url;

  WebClient([this.url = defaultUrl]);

  Future<List<String>> getInfo() async {
    try {
      var response = await http.get(Uri.parse('$url/info/'));
      if (response.statusCode == 200) {
        var info = json.decode(response.body);
        return List<String>.from(info['strategies']);
      } else {
        print('Failed: HTTP ${response.statusCode}');
        return ['Random', 'Smart'];
      }
    } catch (e) {
      print('Error retrieving info: $e');
      return ['Random', 'Smart'];
    }
  }
}

class ConsoleUI {
  late Board _board;

  void showMessage(String msg) {
    print(msg);
  }

  String promptServerUrl(String defaultUrl) {
    stdout.write('Enter the C4 server URL [default=$defaultUrl]: ');
    var url = stdin.readLineSync();
    if (url == null || url.trim().isEmpty) {
      url = defaultUrl;
    }
    return url!;
  }

  String promptStrategy(List<String> strategies) {
    var prompt = strategies
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join(' ');
    stdout.write('Select the server strategy: $prompt: ');
    stdin.readLineSync(); // Currently always selects the first for mockup
    return strategies[0];
  }

  /// Prompt for the next move and return a 0-based slot index.
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
      stdout.writeln('Invalid selection: $line');
    }
  }

  void showBoard() {
    for (var row in _board.rows) {
      var line = row.map((player) => player.token).join(' ');
      stdout.writeln(line);
    }
    var indexes = List<int>.generate(_board.width, (i) => i + 1).join(' ');
    stdout.writeln(indexes);
  }
}

class Board {
  final int width;
  final int height;

  Board([this.width = 7, this.height = 6]);

  /// Is the slot at the given 0-based index full?
  bool isSlotFull(int i) {
    // TODO: mockup code for testing
    return i % 2 == 0;
  }

  /// Placeholder rows for testing showBoard
  List<List<Player>> get rows {
    return List.generate(
      height,
      (_) => List.generate(width, (_) => Player('.')),
    );
  }
}

class Player {
  String token;
  Player(this.token);
}
