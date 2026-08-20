// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene_tic_tac_toe/game/game_controller.dart';

void main() {
  test('GameController marks moves and identifies horizontal win', () {
    final controller = GameController();
    expect(controller.currentTurn, CellState.x);

    // X moves 0, O moves 3, X moves 1, O moves 4, X moves 2
    controller.makeMove(0);
    controller.onPieceSpawnFinished();
    expect(controller.currentTurn, CellState.o);

    controller.makeMove(3);
    controller.onPieceSpawnFinished();
    expect(controller.currentTurn, CellState.x);

    controller.makeMove(1);
    controller.onPieceSpawnFinished();
    expect(controller.currentTurn, CellState.o);

    controller.makeMove(4);
    controller.onPieceSpawnFinished();
    expect(controller.currentTurn, CellState.x);

    controller.makeMove(2);
    expect(controller.winResult?.winner, CellState.x);
    expect(controller.winResult?.winningIndices, [0, 1, 2]);
  });
}
