//this is code that needs to be implemented within our main



import 'package:http/http.dart' as http;

void main() async {
  var url = Uri.parse('https://www.cs.utep.edu/cheon/cs3360/project/c4/info/');
  var response = await http.get(url);
  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');
}



// Fill in the Blank
// 6
// /
// 7
// Grade: 6 out of 7 points possible
// Complete the following Dart program by filling in the missing parts. Your program should:

// Prompt the user for a C4 server URL,
// Call the server’s info API,
// Decode the JSON response, and
// Print the supported strategies.


import 'package:http/http.dart' as http;

import 'dart:io';

import 'dart:io';



void main() async {

 const defaultUrl = 'https://www.cs.utep.edu/cheon/cs3360/project/c4/';

 stdout.writeln('Welcome to C4!');

 stdout.write('Enter the C4 server URL \[default=$defaultUrl]: ');

 var url = stdin.readLineSync();

 if (url!.trim().isEmpty) {

  url = defaultUrl;

 }

 url = '$url/info/';



 stdout.writeln('Retrieving info ...');

 var response = await http.get(Uri.parse(url));

 if (response.statusCode == 200) { // HTTP OK

  var info = json.decode(response.body);

  stdout.writeln('Supported strategy: ${info\['strategies']}');

 } else {

  stdout.writeln('Failed: HTTP ${response.statusCode}');

 }

}



// You will refactor the C4 info app code into an object-oriented structure by introducing the following classes:

// Controller: Coordinates tasks.
// ConsoleUI: Handles user interaction (I/O), e.g., prompting the user for input.
// WebClient: Accesses the web service, e.g., calling the info API.
// Complete the following Dart code by filling in the missing keywords or expressions. Enter only one word for each blank.



import 'package:http/http.dart' as http;

import 'dart:io';

import 'dart:convert';



void main() async {

 Controller().start();

}



class Controller {



 void start() async {

  var ui = ConsoleUI();

  ui.showMessage('Welcome to C4!');

  var url = ui.askServerUrl(WebClient.defaultUrl);

  ui.showMessage('Retrieving info ...');

  var net = WebClient();

  var strategies = await net.getInfo();

  ui.promptStrategy(strategies);

 }

}



class WebClient {

 static const defaultUrl = 'https://www.cs.utep.edu/cheon/cs3360/project/c4/';



 getInfo() async {

  // TODO: mockup code - replace with real logic

  return \['Random', 'Smart'];

 }

}



class ConsoleUI {



 void showMessage(String msg) {

  print(msg);

 }



 String promptServerUrl(String defaultUrl) {

  stdout.write('Enter the C4 server URL \[default=$defaultUrl]: ');

  var url = stdin.readLineSync();

  if (url!.trim().isEmpty) {

   url = defaultUrl;

  }

  return url!;

 }



 String promptStrategy(List<String> strategies) {

  // TODO: Mockup code - replace with real logic

  var prompt = '1. ${strategies\[0]} 2. ${strategies\[1]}';

  stdout.write('Select the server strategy: $prompt: ');

  stdin.readLineSync();

  return strategies\[0];

 }

}


// Implement a method named promptMove() in the ConsoleUI class. This method should prompt the user to enter the number of an open slot. Complete the method by filling in the provided template code. Refer to the lecture notes for guidance and hints on how to implement the logic.



class ConsoleUI {

 late Board _board;



 /// Prompt for the next move and return a 0-based slot index.

 int promptMove() {

  while (true) {

   stdout.write('Select a slot \[1-${_board.width}]: ');

   var line = stdin.readLineSync()!.trim();

   try {

    var response = int.parse(line);

    if (response >= 1

      && response <= _board.width

      && !_board.isSlotFull(response - 1)) {

     return response - 1;

    }

   } on FormatException {}

   stdout.writeln('Invalid selection: $line');

  }

 }



 // other fields and methods ...

}



class Board {

 final int width;

 final int height;



 Board(\[this.width = 7, this.height = 6]);



 /// Is the slot at the given 0-based index full?

 bool isSlotFull(int i) {

  // TODO: mockup code for testing

  return i % 2 == 0;

 }

}

// Complete the missing parts of the showBoard() method in Dart to display the current board configuration using higher-order collection methods.



// You may assume that the Board class provides two getters:

// width: returns the board width
// rows: returns all rows as a list of lists
// Each player has a token 'O', 'X', or '.', where '.' represents an empty space.



void showBoard() {

 for (var row in _board.rows) {          

  var line = row.map((player) => player.token)

          .join(' ');           

  stdout.writeln(line);

 }

 var indexes = List<int>.generate(_board.width, (i) => i+1).join(' ');

 stdout.writeln(indexes);

}