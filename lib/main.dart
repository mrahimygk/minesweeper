import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';

enum TileState { covered, blown, open, flagged, revealed }

///* use index +1 for difficulty multiplier
enum Difficulty { HARD, MEDIUM, EASY }

final int rows = 8;
final int cols = 8;

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.grey[700], //or set color with: Color(0xFF0000FF)
  ));
  runApp(MineSweeper());
}

class MineSweeper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mine Sweaper',
      home: Board(),
      theme: ThemeData(
          fontFamily: 'IranSans',
          appBarTheme: AppBarTheme(
            elevation: 0.0,
          ),
          accentColor: Colors.red),
    );
  }
}

class Board extends StatefulWidget {
  @override
  BoardState createState() => BoardState();
}

class BoardState extends State<Board> with TickerProviderStateMixin {
  static final difficulty = Difficulty.EASY;
  static final int baseMines = 8;
  final int numOfMines =
      baseMines + (baseMines * (1.0 / (difficulty.index + 1.0))).floor();

  List<List<TileState>> uiState;
  List<List<bool>> tiles;

  AnimationController _controller;

  bool alive;
  bool won;
  int minesFound;
  Timer timer;
  Stopwatch stopwatch = Stopwatch();

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void resetBoard() {
    alive = true;
    won = false;
    minesFound = 0;
    stopwatch.reset();

    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {});
    });
    uiState = List<List<TileState>>.generate(rows, (row) {
      return List<TileState>.filled(cols, TileState.covered);
    });

    tiles = List<List<bool>>.generate(rows, (row) {
      return List<bool>.filled(cols, false);
    });

    Random random = Random();
    int rem = numOfMines;
    //TODO: add loading indicator
    while (rem > 0) {
      int pos = random.nextInt(rows * cols);
      int r = pos ~/ rows;
      int c = pos % cols;
      if (!tiles[r][c]) {
        tiles[r][c] = true;
        rem--;
      }
    }

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );
  }

  @override
  void initState() {
    resetBoard();
    super.initState();
  }

  Widget buildBoard(BuildContext context) {
    bool hasCoveredCell = false;
    List<Row> boardRow = <Row>[];
    boardRow.add(Row());
    for (int y = 0; y < rows; y++) {
      List<Widget> rowsChildren = <Widget>[];
      for (int x = 0; x < cols; x++) {
        TileState state = uiState[y][x];
        int count = mineCount(x, y);

        if (!alive) {
          if (state != TileState.blown) {
            state = tiles[y][x] ? TileState.revealed : state;
          }
        }

        if (state == TileState.covered || state == TileState.flagged) {
          _controller.forward();
          rowsChildren.add(
            GestureDetector(
              onTap: () {
                print('tapped on $y $x');
                if (state == TileState.covered) {
                  probe(x, y);
                }
              },
              onLongPress: () {
                flag(x, y);
              },
              child: Listener(
                child: FadeTransition(
                  opacity: _controller,
                  child: CoveredMineTile(
                    flagged: state == TileState.flagged,
                    posX: x,
                    posY: y,
                  ),
                ),
              ),
            ),
          );
          if (state == TileState.covered) {
            hasCoveredCell = true;
          }
        } else {
          rowsChildren.add(OpenMineTile(state, count, () {
            print("clicked on $count, at ($x,$y)");
            openNeighbours(x, y, count);
          }));
        }
      }
      boardRow.add(Row(
        children: rowsChildren,
        mainAxisAlignment: MainAxisAlignment.center,
        key: ValueKey<int>(y),
      ));
    }

    if (!hasCoveredCell) {
      if ((minesFound == numOfMines) && alive) {
        won = true;
        stopwatch.stop();
      }
    }

    return Container(
      color: Colors.grey[700],
      padding: EdgeInsets.all(10.0),
      child: Column(
        children: boardRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int timeElapsed = stopwatch.elapsedMilliseconds ~/ 1000;
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomPadding: false,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text('مین ‌روب'),
          backgroundColor: Colors.grey[700],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(45.0),
            child: Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: OutlineButton(
                    borderSide: BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(),
                    child: Text(
                      "از اول",
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () => resetBoard(),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey[700],
                    alignment: Alignment.center,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                            color: won
                                ? Colors.green
                                : alive ? Colors.white : Colors.red,
                            fontFamily: 'IranSans'),
                        text: won
                            ? "بردی بازی رو! در $timeElapsed  ثانیه"
                            : alive
                                ? "[مین‌ها: $minesFound از $numOfMines] [$timeElapsed ثانیه]"
                                : "باختی! $timeElapsed  ثانیه",
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        body: Center(
          child: Container(
            color: Colors.grey[50],
            child: Center(
              child: buildBoard(context),
            ),
          ),
        ),
      ),
    );
  }

  void probe(int x, int y) {
    if (!alive) return;
    if (uiState[y][x] == TileState.flagged) return;
    setState(() {
      if (tiles[y][x]) {
        uiState[y][x] = TileState.blown;
        alive = false;
        timer.cancel();
      } else {
        open(x, y);
        if (!stopwatch.isRunning) stopwatch.start();
      }
    });
  }

  void open(int x, int y) {
    if (!inBoard(x, y)) return;
    if (uiState[y][x] == TileState.open) return;
    uiState[y][x] = TileState.open;

    if (mineCount(x, y) > 0) return;

    open(x + 1, y);
    open(x - 1, y);
    open(x, y + 1);
    open(x, y - 1);
    open(x - 1, y - 1);
    open(x + 1, y + 1);
    open(x - 1, y + 1);
    open(x + 1, y - 1);
  }

  void openNeighbours(int x, int y, int count) {
    openJustNeighbours(x + 1, y);
    openJustNeighbours(x - 1, y);
    openJustNeighbours(x, y + 1);
    openJustNeighbours(x, y - 1);
    openJustNeighbours(x - 1, y - 1);
    openJustNeighbours(x + 1, y + 1);
    openJustNeighbours(x - 1, y + 1);
    openJustNeighbours(x + 1, y - 1);
  }

  void openJustNeighbours(int x, int y) {
    if (!inBoard(x, y)) return;
    if (uiState[y][x] == TileState.flagged) return;
    uiState[y][x] = TileState.open;
  }

  void flag(int x, int y) {
    if (!alive) return;
    setState(() {
      if (uiState[y][x] == TileState.flagged) {
        uiState[y][x] = TileState.covered;
        --minesFound;
      } else {
        uiState[y][x] = TileState.flagged;
        ++minesFound;
      }
    });
  }

  int mineCount(int x, int y) {
    int count = 0;
    count += bombs(x - 1, y);
    count += bombs(x + 1, y);
    count += bombs(x, y - 1);
    count += bombs(x, y + 1);
    count += bombs(x - 1, y - 1);
    count += bombs(x + 1, y + 1);
    count += bombs(x + 1, y - 1);
    count += bombs(x - 1, y + 1);
    return count;
  }

  int bombs(int x, int y) => inBoard(x, y) && tiles[y][x] ? 1 : 0;

  bool inBoard(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;
}

Widget buildInnerTile(Widget child, double size) {
  return Container(
    padding: EdgeInsets.all(1.0),
    margin: EdgeInsets.all(2.0),
    height: size,
    width: size,
    child: child,
    color: Colors.grey,
  );
}

Widget buildTile(Widget child, double size) {
  return Container(
    padding: EdgeInsets.all(1.0),
    margin: EdgeInsets.all(2.0),
    height: size,
    width: size,
    color: Colors.grey[400],
    child: child,
  );
}

class CoveredMineTile extends StatelessWidget {
  final bool flagged;
  final int posX;
  final int posY;

  const CoveredMineTile({Key key, this.flagged, this.posX, this.posY})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final size = (w - (2 * 10) - (rows * 4)) / rows;
    Widget text;
    if (flagged) {
      text = Center(
        child: RichText(
          text: TextSpan(
              text: "\u2691",
              style: TextStyle(
                fontSize: size / 2,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              )),
          textAlign: TextAlign.center,
        ),
      );
    }

    Widget innerTile = Container(
      padding: EdgeInsets.all(1.0),
      margin: EdgeInsets.all(2.0),
      height: size,
      width: size,
      color: Colors.grey[350],
      child: text,
    );

    return buildTile(innerTile, size);
  }
}

class OpenMineTile extends StatelessWidget {
  final TileState state;
  final int number;
  final Function() onLongPress;

  OpenMineTile(this.state, this.number, this.onLongPress);

  final List textColor = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.cyan,
    Colors.amber,
    Colors.brown,
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    Widget text;

    final w = MediaQuery.of(context).size.width;
    final size = (w - (2 * 10) - (rows * 4)) / rows;

    if (state == TileState.open) {
      if (number != 0) {
        ///number
        text = Center(
          child: RichText(
            text: TextSpan(
              text: '$number',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor[number - 1],
                fontSize: size / 2,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
    } else {
      ///bomb
      text = Center(
        child: RichText(
          text: TextSpan(
            text: '\u2739',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: size / 2,
              color: Colors.red,
            ),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return GestureDetector(
        onLongPress: () {
          onLongPress();
        },
        child: buildInnerTile(text, size));
  }
}
