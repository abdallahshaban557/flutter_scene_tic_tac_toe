import 'package:flutter/foundation.dart';

enum CellState { empty, x, o }

enum GameMode { singlePlayer, twoPlayer }

enum GameStatus { playing, pieceSpawning, winningCelebration, eatingLosers, ended }

class WinResult {
  final CellState winner;
  final List<int> winningIndices; // e.g. [0, 1, 2]

  const WinResult({required this.winner, required this.winningIndices});
}

class GameController extends ChangeNotifier {
  List<CellState> _board = List.filled(9, CellState.empty);
  CellState _currentTurn = CellState.x;
  GameMode _mode = GameMode.singlePlayer;
  GameStatus _status = GameStatus.playing;
  WinResult? _winResult;

  int _xScore = 0;
  int _oScore = 0;
  int _tieScore = 0;

  // Eating animation tracking
  int? _eatingWinnerIndex; // The winning piece currently eating
  int? _currentlyTargetedLoserIndex; // The loser piece currently being eaten
  List<int> _remainingLoserIndices = [];
  String _statusMessage = "Player X's Turn";

  List<CellState> get board => List.unmodifiable(_board);
  CellState get currentTurn => _currentTurn;
  GameMode get mode => _mode;
  GameStatus get status => _status;
  WinResult? get winResult => _winResult;
  int get xScore => _xScore;
  int get oScore => _oScore;
  int get tieScore => _tieScore;
  int? get eatingWinnerIndex => _eatingWinnerIndex;
  int? get currentlyTargetedLoserIndex => _currentlyTargetedLoserIndex;
  List<int> get remainingLoserIndices => List.unmodifiable(_remainingLoserIndices);
  String get statusMessage => _statusMessage;

  // Callback to trigger 3D animations in scene
  void Function(int index, CellState piece)? onPiecePlaced;
  void Function(WinResult winResult, List<int> loserIndices)? onWinTriggered;
  void Function(Map<int, int> winnerToLoserPairs, VoidCallback onWaveDone)? onMultiChompStep;
  void Function()? onFeastCompleted;

  void setGameMode(GameMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    resetGame();
  }

  void resetGame() {
    _board = List.filled(9, CellState.empty);
    _currentTurn = CellState.x;
    _status = GameStatus.playing;
    _winResult = null;
    _eatingWinnerIndex = null;
    _currentlyTargetedLoserIndex = null;
    _remainingLoserIndices.clear();
    _statusMessage = "Player X's Turn";
    notifyListeners();
  }

  void resetScores() {
    _xScore = 0;
    _oScore = 0;
    _tieScore = 0;
    resetGame();
  }

  bool makeMove(int index) {
    if (index < 0 || index >= 9) return false;
    if (_board[index] != CellState.empty) return false;
    if (_status != GameStatus.playing) return false;

    _board[index] = _currentTurn;
    _status = GameStatus.pieceSpawning;
    final placedPiece = _currentTurn;

    onPiecePlaced?.call(index, placedPiece);
    notifyListeners();

    // Check game outcome after placement
    _checkGameOutcome();
    return true;
  }

  void onPieceSpawnFinished() {
    if (_status != GameStatus.pieceSpawning) return;

    if (_winResult != null) {
      _startWinningSequence();
      return;
    }

    if (_isBoardFull()) {
      _status = GameStatus.ended;
      _tieScore++;
      _statusMessage = "It's a Draw! 🤝";
      notifyListeners();
      return;
    }

    // Switch turn
    _currentTurn = (_currentTurn == CellState.x) ? CellState.o : CellState.x;
    _status = GameStatus.playing;
    _statusMessage = _currentTurn == CellState.x
        ? "Player X's Turn"
        : (_mode == GameMode.singlePlayer
            ? "AI (O) is thinking..."
            : "Player O's Turn");
    notifyListeners();

    // Trigger AI move if single player
    if (_mode == GameMode.singlePlayer && _currentTurn == CellState.o) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (_status == GameStatus.playing && _currentTurn == CellState.o) {
          _triggerAiMove();
        }
      });
    }
  }

  void _triggerAiMove() {
    final bestMove = _findBestMove();
    if (bestMove != -1) {
      makeMove(bestMove);
    }
  }

  void _checkGameOutcome() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
      [0, 4, 8], [2, 4, 6], // Diagonals
    ];

    for (final line in lines) {
      final a = _board[line[0]];
      final b = _board[line[1]];
      final c = _board[line[2]];

      if (a != CellState.empty && a == b && b == c) {
        _winResult = WinResult(winner: a, winningIndices: line);
        if (a == CellState.x) {
          _xScore++;
        } else {
          _oScore++;
        }
        return;
      }
    }
  }

  bool _isBoardFull() {
    return !_board.contains(CellState.empty);
  }

  void _startWinningSequence() {
    final win = _winResult!;
    final loser = (win.winner == CellState.x) ? CellState.o : CellState.x;

    // Find all loser pieces on the board to be eaten
    _remainingLoserIndices = [];
    for (int i = 0; i < 9; i++) {
      if (_board[i] == loser) {
        _remainingLoserIndices.add(i);
      }
    }

    _status = GameStatus.winningCelebration;
    final winnerName = win.winner == CellState.x ? "X" : "O";
    _statusMessage = "🎉 $winnerName Wins! Getting hungry...";
    notifyListeners();

    onWinTriggered?.call(win, _remainingLoserIndices);

    // After celebration jump, start the multi-winner eating feast!
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_status == GameStatus.winningCelebration) {
        _startEatingStep();
      }
    });
  }

  void _startEatingStep() {
    if (_remainingLoserIndices.isEmpty) {
      // Feast complete!
      _status = GameStatus.ended;
      final winnerName = _winResult!.winner == CellState.x ? "X" : "O";
      _statusMessage = "😋 $winnerName devoured all opposing pieces!";
      _currentlyTargetedLoserIndex = null;
      _eatingWinnerIndex = null;
      onFeastCompleted?.call();
      notifyListeners();
      return;
    }

    _status = GameStatus.eatingLosers;
    final winner = _winResult!.winner;

    // Collect all winner indices on the board
    final allWinnerIndices = <int>[];
    for (final idx in _winResult!.winningIndices) {
      if (!allWinnerIndices.contains(idx)) allWinnerIndices.add(idx);
    }
    for (int i = 0; i < 9; i++) {
      if (_board[i] == winner && !allWinnerIndices.contains(i)) {
        allWinnerIndices.add(i);
      }
    }

    // Compute pairwise closest match between winners and losers
    final pairs = _computeClosestPairs(allWinnerIndices, _remainingLoserIndices);

    final winnerName = winner == CellState.x ? "X" : "O";
    final loserName = winner == CellState.x ? "O" : "X";
    _statusMessage = "🍴 ${winnerName}s are devouring their closest ${loserName}s!";
    notifyListeners();

    onMultiChompStep?.call(pairs, () {
      // Wave finished: remove eaten losers
      for (final loserIdx in pairs.values) {
        _remainingLoserIndices.remove(loserIdx);
        _board[loserIdx] = CellState.empty;
      }
      notifyListeners();

      // Pause briefly, then check if any remaining losers need a second chomp
      Future.delayed(const Duration(milliseconds: 350), () {
        if (_status == GameStatus.eatingLosers) {
          _startEatingStep();
        }
      });
    });
  }

  Map<int, int> _computeClosestPairs(List<int> winners, List<int> losers) {
    final pairs = <int, int>{};
    final availWinners = List<int>.from(winners);
    final availLosers = List<int>.from(losers);

    while (availWinners.isNotEmpty && availLosers.isNotEmpty) {
      double minDistance = double.infinity;
      int bestW = -1;
      int bestL = -1;

      for (final w in availWinners) {
        final wR = w ~/ 3;
        final wC = w % 3;
        for (final l in availLosers) {
          final lR = l ~/ 3;
          final lC = l % 3;
          final distSq = (wR - lR) * (wR - lR) + (wC - lC) * (wC - lC);
          if (distSq < minDistance) {
            minDistance = distSq.toDouble();
            bestW = w;
            bestL = l;
          }
        }
      }

      if (bestW != -1 && bestL != -1) {
        pairs[bestW] = bestL;
        availWinners.remove(bestW);
        availLosers.remove(bestL);
      } else {
        break;
      }
    }
    return pairs;
  }

  // AI Minimax logic with strategic heuristic
  int _findBestMove() {
    // 1. Check if AI can win in 1 move
    for (int i = 0; i < 9; i++) {
      if (_board[i] == CellState.empty) {
        _board[i] = CellState.o;
        if (_checkWinner() == CellState.o) {
          _board[i] = CellState.empty;
          return i;
        }
        _board[i] = CellState.empty;
      }
    }

    // 2. Check if opponent is about to win, block them
    for (int i = 0; i < 9; i++) {
      if (_board[i] == CellState.empty) {
        _board[i] = CellState.x;
        if (_checkWinner() == CellState.x) {
          _board[i] = CellState.empty;
          return i;
        }
        _board[i] = CellState.empty;
      }
    }

    // 3. Take center if available
    if (_board[4] == CellState.empty) {
      return 4;
    }

    // 4. Take corners if available
    final corners = [0, 2, 6, 8]..shuffle();
    for (final corner in corners) {
      if (_board[corner] == CellState.empty) {
        return corner;
      }
    }

    // 5. Take any remaining empty side
    final sides = [1, 3, 5, 7]..shuffle();
    for (final side in sides) {
      if (_board[side] == CellState.empty) {
        return side;
      }
    }

    return -1;
  }

  CellState _checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final a = _board[line[0]];
      final b = _board[line[1]];
      final c = _board[line[2]];
      if (a != CellState.empty && a == b && b == c) {
        return a;
      }
    }
    return CellState.empty;
  }
}
