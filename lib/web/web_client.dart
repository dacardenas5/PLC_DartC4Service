import 'dart:convert';
import 'package:http/http.dart' as http;

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
