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
  void Function(int winnerIndex, int loserIndex, VoidCallback onChompDone)? onChompStep;
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
      Future.delayed(const Duration(milliseconds: 450), () {
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

    // After celebration jump, start the eating feast!
    Future.delayed(const Duration(milliseconds: 1200), () {
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
    // Primary winner piece is the center of the winning line, or the middle of line
    _eatingWinnerIndex = _winResult!.winningIndices.contains(4)
        ? 4
        : _winResult!.winningIndices[1];

    // Target the first remaining loser piece
    _currentlyTargetedLoserIndex = _remainingLoserIndices.first;
    final winnerName = _winResult!.winner == CellState.x ? "X" : "O";
    final loserName = _winResult!.winner == CellState.x ? "O" : "X";
    _statusMessage = "🍴 $winnerName is chomping $loserName!";
    notifyListeners();

    onChompStep?.call(_eatingWinnerIndex!, _currentlyTargetedLoserIndex!, () {
      // Chomp finished for this piece!
      _remainingLoserIndices.remove(_currentlyTargetedLoserIndex);
      _board[_currentlyTargetedLoserIndex!] = CellState.empty;
      _currentlyTargetedLoserIndex = null;
      notifyListeners();

      // Short pause before chomping the next one
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_status == GameStatus.eatingLosers) {
          _startEatingStep();
        }
      });
    });
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
