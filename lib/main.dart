import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:chess/chess.dart' as chess;

void main() => runApp(const ChessGameApp());

enum GameMode { local, computer }

enum BoardTheme {
  forest(
    'Forest',
    BoardColor.green,
    Color(0xFF193A35),
    Color(0xFFE5F0E8),
    Color(0xFFB8D7C2),
  ),
  walnut(
    'Walnut',
    BoardColor.brown,
    Color(0xFF4A2B20),
    Color(0xFFF5E8D6),
    Color(0xFFDDBA8C),
  ),
  midnight(
    'Midnight',
    BoardColor.darkBrown,
    Color(0xFF1B2034),
    Color(0xFFE7E9F6),
    Color(0xFF9AA8D6),
  ),
  ember(
    'Ember',
    BoardColor.orange,
    Color(0xFF54261C),
    Color(0xFFFFE7D2),
    Color(0xFFE9A06B),
  );

  const BoardTheme(
    this.label,
    this.boardColor,
    this.ink,
    this.surface,
    this.accent,
  );

  final String label;
  final BoardColor boardColor;
  final Color ink;
  final Color surface;
  final Color accent;
}

class ComputerPlayer {
  ComputerPlayer({this.depth = 2});

  final int depth;

  chess.Move? chooseMove(chess.Chess game) {
    final legalMoves = _legalMoves(game);
    chess.Move? bestMove;
    var bestScore = -1000000;

    for (final move in legalMoves) {
      _makeMove(game, move);
      final score = _search(game, depth - 1, -1000000, 1000000);
      game.undo_move();
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  int _search(chess.Chess game, int remainingDepth, int alpha, int beta) {
    if (game.game_over) return _terminalScore(game);
    if (remainingDepth == 0) return _evaluate(game);

    final maximizing = game.turn == chess.Color.BLACK;
    var best = maximizing ? -1000000 : 1000000;
    for (final move in _legalMoves(game)) {
      _makeMove(game, move);
      final score = _search(game, remainingDepth - 1, alpha, beta);
      game.undo_move();

      if (maximizing) {
        best = score > best ? score : best;
        alpha = alpha > best ? alpha : best;
      } else {
        best = score < best ? score : best;
        beta = beta < best ? beta : best;
      }
      if (beta <= alpha) break;
    }
    return best;
  }

  List<chess.Move> _legalMoves(chess.Chess game) {
    return List<chess.Move>.from(game.moves({'asObjects': true}));
  }

  void _makeMove(chess.Chess game, chess.Move move) {
    game.move({
      'from': move.fromAlgebraic,
      'to': move.toAlgebraic,
      if (move.promotion != null) 'promotion': _promotionName(move.promotion!),
    });
  }

  String _promotionName(chess.PieceType type) {
    switch (type) {
      case chess.PieceType.QUEEN:
        return 'q';
      case chess.PieceType.ROOK:
        return 'r';
      case chess.PieceType.BISHOP:
        return 'b';
      case chess.PieceType.KNIGHT:
        return 'n';
      default:
        return 'q';
    }
  }

  int _terminalScore(chess.Chess game) {
    if (!game.in_checkmate) return 0;
    return game.turn == chess.Color.BLACK ? -100000 : 100000;
  }

  int _evaluate(chess.Chess game) {
    final values = <chess.PieceType, int>{
      chess.PieceType.PAWN: 100,
      chess.PieceType.KNIGHT: 320,
      chess.PieceType.BISHOP: 330,
      chess.PieceType.ROOK: 500,
      chess.PieceType.QUEEN: 900,
      chess.PieceType.KING: 20000,
    };
    var score = 0;
    for (var index = 0; index < game.board.length; index++) {
      if ((index & 0x88) != 0) continue;
      final piece = game.board[index];
      if (piece == null) continue;
      final value = values[piece.type] ?? 0;
      score += piece.color == chess.Color.BLACK ? value : -value;
    }
    return score;
  }
}

class ChessGameApp extends StatelessWidget {
  const ChessGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1E252B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Chess',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6B5B)),
        fontFamily: 'Georgia',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: Color(0xFF5E625D)),
        ),
      ),
      home: const ChessPage(),
    );
  }
}

class ChessPage extends StatefulWidget {
  const ChessPage({super.key});

  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  ChessBoardController _controller = ChessBoardController();
  final List<String> _positionHistory = [];
  GameMode _gameMode = GameMode.computer;
  BoardTheme _boardTheme = BoardTheme.forest;
  int _computerDepth = 3;
  String? _selectedSquare;
  bool _resultDialogShown = false;
  bool _computerThinking = false;
  bool _gameStarted = false;
  bool _homeComputerSelected = false;

  Chess get _game => _controller.game;

  @override
  void initState() {
    super.initState();
    _positionHistory.add(_game.fen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleMove() {
    _recordPosition();
    setState(() => _selectedSquare = null);
    if (_finishGameIfNeeded()) return;
    if (_gameMode == GameMode.computer && _game.turn == Chess.BLACK) {
      _playComputerMove();
    }
  }

  void _resetGame() {
    _controller.resetBoard();
    setState(() {
      _positionHistory
        ..clear()
        ..add(_game.fen);
      _resultDialogShown = false;
      _computerThinking = false;
      _selectedSquare = null;
    });
  }

  void _undoMove() {
    if (_computerThinking || _game.history.isEmpty) return;
    _undoSingleMove();
    if (_gameMode == GameMode.computer && _game.history.isNotEmpty) {
      _undoSingleMove();
    }
    setState(() {
      _resultDialogShown = false;
    });
  }

  void _undoSingleMove() {
    final previousGame = _game.copy();
    previousGame.undo_move();
    _replaceController(previousGame);
    if (_positionHistory.length > 1) _positionHistory.removeLast();
  }

  void _recordPosition() {
    final fen = _game.fen;
    if (_positionHistory.isEmpty || _positionHistory.last != fen) {
      _positionHistory.add(fen);
    }
  }

  void _startGame(GameMode mode) {
    _resetGame();
    setState(() {
      _gameMode = mode;
      _gameStarted = true;
    });
  }

  void _returnHome() {
    _resetGame();
    setState(() {
      _gameStarted = false;
      _homeComputerSelected = false;
    });
  }

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GameReviewPage(
          positions: List<String>.unmodifiable(_positionHistory),
          moves: List<String>.unmodifiable(
            _game.san_moves().whereType<String>(),
          ),
          result: _resultTitle,
          boardTheme: _boardTheme,
        ),
      ),
    );
  }

  void _replaceController(chess.Chess game) {
    final previousController = _controller;
    _controller = ChessBoardController.fromGame(game);
    previousController.dispose();
  }

  void _handleBoardTap(TapUpDetails details, double boardSize) {
    if (_game.game_over || _computerThinking) return;
    if (_gameMode == GameMode.computer && _game.turn != Chess.WHITE) return;

    final squareSize = boardSize / 8;
    final column = (details.localPosition.dx / squareSize).floor();
    final row = (details.localPosition.dy / squareSize).floor();
    if (column < 0 || column > 7 || row < 0 || row > 7) return;
    final square = '${String.fromCharCode(97 + column)}${8 - row}';
    final piece = _game.get(square);

    if (_selectedSquare == null) {
      if (piece?.color == _game.turn) {
        setState(() => _selectedSquare = square);
      }
      return;
    }

    if (piece?.color == _game.turn) {
      setState(() => _selectedSquare = square);
      return;
    }

    final legalTargets = List<dynamic>.from(
      _game.moves({'square': _selectedSquare}),
    );
    if (legalTargets.contains(square)) {
      _controller.makeMove(from: _selectedSquare!, to: square);
      _handleMove();
    } else {
      setState(() => _selectedSquare = null);
    }
  }

  bool _finishGameIfNeeded() {
    if (!_game.game_over || _resultDialogShown) return _game.game_over;
    _resultDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showResultDialog();
    });
    return true;
  }

  Future<void> _playComputerMove() async {
    if (_computerThinking || _game.game_over || _game.turn != Chess.BLACK) {
      return;
    }
    setState(() => _computerThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || _gameMode != GameMode.computer || _game.game_over) return;

    final move = ComputerPlayer(depth: _computerDepth).chooseMove(_game);
    if (move != null) {
      final nextGame = _game.copy();
      nextGame.move({
        'from': move.fromAlgebraic,
        'to': move.toAlgebraic,
        if (move.promotion != null)
          'promotion': _promotionName(move.promotion!),
      });
      _replaceController(nextGame);
      _recordPosition();
    }
    if (!mounted) return;
    setState(() => _computerThinking = false);
    _finishGameIfNeeded();
  }

  String _promotionName(chess.PieceType type) {
    switch (type) {
      case chess.PieceType.QUEEN:
        return 'q';
      case chess.PieceType.ROOK:
        return 'r';
      case chess.PieceType.BISHOP:
        return 'b';
      case chess.PieceType.KNIGHT:
        return 'n';
      default:
        return 'q';
    }
  }

  Future<void> _chooseGameMode() async {
    final selectedMode = await showDialog<GameMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose game mode'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, GameMode.local),
            child: ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Two players'),
              subtitle: Text(
                _gameMode == GameMode.local
                    ? 'Selected'
                    : 'Pass and play locally',
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, GameMode.computer),
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text('Play computer'),
              subtitle: Text('You play White against the computer'),
            ),
          ),
        ],
      ),
    );
    if (selectedMode == null || selectedMode == _gameMode) return;
    setState(() => _gameMode = selectedMode);
    _resetGame();
  }

  void _showOnlineInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Online multiplayer'),
        content: const Text(
          'This project currently has no authentication or game server. '
          'A production online mode needs a backend for rooms, player identity, '
          'move validation, reconnection, and synchronized game state.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseBoardTheme() async {
    final selectedTheme = await showModalBottomSheet<BoardTheme>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your table',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Every palette changes the board and the room around it.',
              ),
              const SizedBox(height: 16),
              for (final theme in BoardTheme.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _ThemeSwatch(
                    theme: theme,
                    selected: theme == _boardTheme,
                  ),
                  title: Text(
                    theme.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: theme == _boardTheme
                      ? const Icon(Icons.check_circle_rounded)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, theme),
                ),
            ],
          ),
        ),
      ),
    );
    if (selectedTheme == null || selectedTheme == _boardTheme) return;
    setState(() => _boardTheme = selectedTheme);
  }

  String get _turnLabel =>
      _game.turn == Chess.WHITE ? 'White to move' : 'Black to move';

  String get _resultTitle {
    if (_game.in_checkmate) {
      final winner = _game.turn == Chess.WHITE ? 'Black' : 'White';
      return '$winner wins by checkmate';
    }
    if (_game.in_stalemate) return 'Draw by stalemate';
    if (_game.insufficient_material) return 'Draw by insufficient material';
    if (_game.in_threefold_repetition) return 'Draw by repetition';
    return 'Draw by the fifty-move rule';
  }

  Future<void> _showResultDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_resultTitle),
        content: Text(
          _game.in_checkmate
              ? 'The king has no legal escape. Excellent game.'
              : 'No legal continuation remains. Well played by both sides.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _openReview();
            },
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Review match'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_gameStarted) return _buildHome();
    return Scaffold(
      backgroundColor: Color.lerp(
        _boardTheme.surface,
        const Color(0xFFF4F1EA),
        0.34,
      ),
      appBar: AppBar(
        backgroundColor: _boardTheme.ink.withAlpha(235),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 24,
        title: const Text(
          'CHESS ROOM',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _returnHome,
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            onPressed: _chooseBoardTheme,
            tooltip: 'Choose board theme',
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            onPressed: _chooseGameMode,
            tooltip: 'Choose game mode',
            icon: Icon(
              _gameMode == GameMode.computer
                  ? Icons.smart_toy_outlined
                  : Icons.people_alt_outlined,
            ),
          ),
          IconButton(
            onPressed: _resetGame,
            tooltip: 'Reset game',
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = (constraints.maxWidth - 32)
                .clamp(280.0, 580.0)
                .toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _boardTheme.ink,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            // The board mutates this controller; the controller's Chess
                            // instance remains the source of truth for every game state.
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) =>
                                  _handleBoardTap(details, boardSize - 16),
                              child: Stack(
                                children: [
                                  ChessBoard(
                                    key: ValueKey(
                                      '${_boardTheme.name}-${_game.history.length}',
                                    ),
                                    controller: _controller,
                                    size: boardSize - 16,
                                    boardColor: _boardTheme.boardColor,
                                    boardOrientation: PlayerColor.white,
                                    enableUserMoves:
                                        !_game.game_over &&
                                        !_computerThinking &&
                                        (_gameMode == GameMode.computer ||
                                            _game.turn == Chess.WHITE),
                                    onMove: _handleMove,
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _BoardFeedbackPainter(
                                          selectedSquare: _selectedSquare,
                                          legalTargets: _selectedSquare == null
                                              ? const []
                                              : List<String>.from(_game.moves({
                                                  'square': _selectedSquare,
                                                })),
                                          captureTargets: _selectedSquare == null
                                              ? const []
                                              : List<String>.from(_game.moves({
                                                  'square': _selectedSquare,
                                                })).where((square) => _game.get(square) != null).toList(),
                                          lastMoveFrom: _game.history.isEmpty
                                              ? null
                                              : _game.history.last.move.fromAlgebraic,
                                          lastMoveTo: _game.history.isEmpty
                                              ? null
                                              : _game.history.last.move.toAlgebraic,
                                          progress: 1,
                                        ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildHistoryPanel(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHome() {
    const difficultyNames = ['Casual', 'Easy', 'Club', 'Advanced', 'Maximum'];
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0E8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : 20,
                  vertical: wide ? 32 : 18,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildHomeHero()),
                            const SizedBox(width: 28),
                            SizedBox(
                              width: 420,
                              child: _buildHomeControls(difficultyNames),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHomeHero(),
                            const SizedBox(height: 18),
                            _buildHomeControls(difficultyNames),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHomeHero() {
    return Container(
      height: 290,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173B35), Color(0xFF315F53)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x2A173B35), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: 28,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB9D1BF),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
                ),
                child: _buildMiniChessboard(),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [const Color(0xFF173B35).withAlpha(240), const Color(0xFF173B35).withAlpha(20)],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('CHESS ROOM', style: TextStyle(color: Color(0xFFCDE2D3), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
                SizedBox(height: 10),
                Text('Your next move\nstarts here.', style: TextStyle(color: Colors.white, fontSize: 34, height: 1.05, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChessboard() {
    final pieces = <int, String>{
      0: '♜', 1: '♞', 2: '♝', 3: '♛', 4: '♚', 5: '♝', 6: '♞', 7: '♜',
      8: '♟', 9: '♟', 10: '♟', 11: '♟', 12: '♟', 13: '♟', 14: '♟', 15: '♟',
      48: '♙', 49: '♙', 50: '♙', 51: '♙', 52: '♙', 53: '♙', 54: '♙', 55: '♙',
      56: '♖', 57: '♘', 58: '♗', 59: '♕', 60: '♔', 61: '♗', 62: '♘', 63: '♖',
    };
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 64,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemBuilder: (context, index) {
        final light = ((index ~/ 8) + index) % 2 == 0;
        final piece = pieces[index];
        return ColoredBox(
          color: light ? const Color(0xFFEEF4E9) : const Color(0xFF7FA58D),
          child: Center(
            child: Text(piece ?? '', style: TextStyle(fontSize: 18, color: index >= 48 ? const Color(0xFFFFFFFF) : const Color(0xFF263A34), shadows: index < 48 ? null : const [Shadow(color: Colors.black26, blurRadius: 2)])),
          ),
        );
      },
    );
  }

  Widget _buildHomeControls(List<String> difficultyNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Choose a game', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _buildModeCard(
          icon: Icons.smart_toy_outlined,
          title: 'Play computer',
          subtitle: 'Challenge an adjustable opponent',
          selected: _homeComputerSelected,
          onTap: () => setState(() => _homeComputerSelected = true),
        ),
        const SizedBox(height: 10),
        _buildModeCard(
          icon: Icons.people_alt_outlined,
          title: 'Play a friend',
          subtitle: 'Two players on one device',
          selected: false,
          onTap: () {
            setState(() => _homeComputerSelected = false);
            _startGame(GameMode.local);
          },
        ),
        const SizedBox(height: 10),
        _buildModeCard(
          icon: Icons.public_outlined,
          title: 'Online multiplayer',
          subtitle: 'Unavailable - local multiplayer only',
          selected: false,
          onTap: _showOnlineInfo,
        ),
        if (_homeComputerSelected) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDED9CB))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Computer intelligence', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE5EFE7), borderRadius: BorderRadius.circular(20)),
                      child: Text(difficultyNames[_computerDepth - 1], style: const TextStyle(color: Color(0xFF315F53), fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
                Slider(
                  value: _computerDepth.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: difficultyNames[_computerDepth - 1],
                  activeColor: const Color(0xFF315F53),
                  onChanged: (value) => setState(() => _computerDepth = value.round()),
                ),
                const Text('Choose how deeply the opponent evaluates each position.', style: TextStyle(fontSize: 12, color: Color(0xFF777B74))),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF173B35), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _startGame(GameMode.computer),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start match', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFE4EFE7) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF315F53) : const Color(0xFFDDD7C8), width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: selected ? const Color(0xFF315F53) : const Color(0xFFF0EDE4), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: selected ? Colors.white : const Color(0xFF315F53))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF777B74), fontSize: 12))])),
              Icon(selected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: selected ? 20 : 15, color: selected ? const Color(0xFF315F53) : const Color(0xFF777B74)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isWhiteTurn = _game.turn == Chess.WHITE;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPlayer('White', 'You', isWhiteTurn, true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VS',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8D918A),
                ),
              ),
            ),
            Expanded(
              child: _buildPlayer(
                'Black',
                _gameMode == GameMode.computer ? 'Computer' : 'Player 2',
                !isWhiteTurn,
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: isWhiteTurn
                ? const Color(0xFFFDFCF8)
                : const Color(0xFF252D30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isWhiteTurn
                  ? const Color(0xFFD8D1C2)
                  : const Color(0xFF252D30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: isWhiteTurn ? const Color(0xFFC5A35A) : const Color(0xFFE9E4D9)),
              const SizedBox(width: 9),
              Text(
                _game.game_over ? 'Game complete' : _computerThinking ? 'Computer is thinking' : _turnLabel,
                style: TextStyle(color: isWhiteTurn ? const Color(0xFF343A38) : const Color(0xFFF7F3EA), fontWeight: FontWeight.w700),
              ),
              if (_game.in_check && !_game.game_over) ...[
                const SizedBox(width: 8),
                const Text('CHECK', style: TextStyle(color: Color(0xFFB7684A), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 16, color: _boardTheme.ink),
            const SizedBox(width: 7),
            Text(
              _game.game_over
                  ? 'Replay the match when you are ready'
                  : _computerThinking
                      ? 'Watch the computer calculate...'
                      : _selectedSquare != null
                          ? 'Piece selected - tap its destination'
                          : 'Tap a piece, then tap its destination',
              style: TextStyle(color: _boardTheme.ink, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayer(String name, String subtitle, bool active, bool isWhite) {
    final captured = _capturedPieces(isWhite ? Chess.BLACK : Chess.WHITE);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7E2D7) : const Color(0xFFEDE9E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFFB9AC94) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: isWhite
                ? const Color(0xFFFDFCF8)
                : const Color(0xFF293236),
            child: Icon(
              Icons.person_rounded,
              size: 20,
              color: isWhite
                  ? const Color(0xFF6C716C)
                  : const Color(0xFFECE7DB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF777B74),
                  ),
                ),
                if (captured.isNotEmpty)
                  Text(
                    'Captured ${captured.join(' ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8D6654),
                    ),
                  ),
              ],
            ),
          ),
          if (active)
            const Icon(Icons.circle, size: 8, color: Color(0xFF4B886D)),
        ],
      ),
    );
  }

  List<String> _capturedPieces(chess.Color capturedColor) {
    final symbols = <PieceType, String>{
      PieceType.QUEEN: 'Q',
      PieceType.ROOK: 'R',
      PieceType.BISHOP: 'B',
      PieceType.KNIGHT: 'N',
      PieceType.PAWN: 'P',
    };
    return [
      for (final state in _game.history)
        if (state.move.captured != null && state.move.color != capturedColor)
          symbols[state.move.captured] ?? '',
    ];
  }

  Widget _buildHistoryPanel() {
    final sanMoves = _game.san_moves().whereType<String>().toList();
    final rows = <String>[];
    for (var index = 0; index < sanMoves.length; index += 2) {
      final moveNumber = (index ~/ 2) + 1;
      final blackMove = index + 1 < sanMoves.length ? sanMoves[index + 1] : '';
      rows.add(
        '$moveNumber. ${sanMoves[index]}${blackMove.isEmpty ? '' : '  $blackMove'}',
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E5DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8D1C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Move history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${sanMoves.length} moves',
                style: const TextStyle(fontSize: 12, color: Color(0xFF777B74)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(minHeight: 54, maxHeight: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: rows.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Moves will appear here',
                      style: TextStyle(color: Color(0xFF92948D)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        rows[index],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _game.history.isEmpty || _computerThinking
                      ? null
                      : _undoMove,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Undo move'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _resetGame,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset game'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardFeedbackPainter extends CustomPainter {
  const _BoardFeedbackPainter({
    required this.selectedSquare,
    required this.legalTargets,
    required this.captureTargets,
    required this.lastMoveFrom,
    required this.lastMoveTo,
    required this.progress,
  });

  final String? selectedSquare;
  final List<String> legalTargets;
  final List<String> captureTargets;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final squareWidth = size.width / 8;
    final squareHeight = size.height / 8;
    final lastMovePaint = Paint()
      ..color = const Color(0x6694B66E).withAlpha((102 * progress).round());
    for (final square in [lastMoveFrom, lastMoveTo]) {
      if (square != null) {
        canvas.drawRect(
          _squareRect(square, squareWidth, squareHeight),
          lastMovePaint,
        );
      }
    }

    if (selectedSquare == null) return;
    final selectedPaint = Paint()
      ..color = const Color(0x8896BD75).withAlpha((136 * progress).round());
    canvas.drawRect(
      _squareRect(selectedSquare!, squareWidth, squareHeight),
      selectedPaint,
    );

    for (final target in legalTargets) {
      final center = _squareCenter(target, squareWidth, squareHeight);
      final isCapture = captureTargets.contains(target);
      final targetPaint = Paint()
        ..color = const Color(0xAA263B32).withAlpha((170 * progress).round())
        ..style = isCapture ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = squareWidth * 0.07;
      canvas.drawCircle(
        center,
        squareWidth * (isCapture ? 0.34 : 0.13),
        targetPaint,
      );
    }
  }

  Rect _squareRect(String square, double squareWidth, double squareHeight) {
    final column = square.codeUnitAt(0) - 97;
    final row = 8 - int.parse(square[1]);
    return Rect.fromLTWH(
      column * squareWidth,
      row * squareHeight,
      squareWidth,
      squareHeight,
    );
  }

  Offset _squareCenter(String square, double squareWidth, double squareHeight) {
    final rect = _squareRect(square, squareWidth, squareHeight);
    return rect.center;
  }

  @override
  bool shouldRepaint(covariant _BoardFeedbackPainter oldDelegate) => true;
}

class GameReviewPage extends StatefulWidget {
  const GameReviewPage({
    super.key,
    required this.positions,
    required this.moves,
    required this.result,
    required this.boardTheme,
  });

  final List<String> positions;
  final List<String> moves;
  final String result;
  final BoardTheme boardTheme;

  @override
  State<GameReviewPage> createState() => _GameReviewPageState();
}

class _GameReviewPageState extends State<GameReviewPage> {
  late final ChessBoardController _controller;
  int _currentPly = 0;

  @override
  void initState() {
    super.initState();
    _controller = ChessBoardController.fromFEN(widget.positions.first);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPly(int ply) {
    final boundedPly = ply.clamp(0, widget.positions.length - 1);
    setState(() => _currentPly = boundedPly);
    _controller.loadFen(widget.positions[boundedPly]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.lerp(
        widget.boardTheme.surface,
        const Color(0xFFF4F1EA),
        0.34,
      ),
      appBar: AppBar(
        backgroundColor: widget.boardTheme.ink.withAlpha(235),
        foregroundColor: Colors.white,
        title: const Text('Match review'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = (constraints.maxWidth - 32)
                .clamp(250.0, 540.0)
                .toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.result,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: widget.boardTheme.ink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: ChessBoard(
                              key: ValueKey(_currentPly),
                              controller: _controller,
                              size: boardSize - 16,
                              boardColor: widget.boardTheme.boardColor,
                              boardOrientation: PlayerColor.white,
                              enableUserMoves: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Previous move',
                            onPressed: _currentPly == 0
                                ? null
                                : () => _showPly(_currentPly - 1),
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          Text(
                            '$_currentPly / ${widget.moves.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            tooltip: 'Next move',
                            onPressed: _currentPly >= widget.moves.length
                                ? null
                                : () => _showPly(_currentPly + 1),
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                        ],
                      ),
                      Slider(
                        value: _currentPly.toDouble(),
                        min: 0,
                        max: widget.moves.length.toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        divisions: widget.moves.isEmpty
                            ? null
                            : widget.moves.length,
                        onChanged: widget.moves.isEmpty
                            ? null
                            : (value) => _showPly(value.round()),
                      ),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9E5DC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD8D1C2)),
                        ),
                        child: widget.moves.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No moves to review.'),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: widget.moves.length,
                                itemBuilder: (context, index) {
                                  final isWhiteMove = index.isEven;
                                  return Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      selected: _currentPly == index + 1,
                                      selectedTileColor: const Color(
                                        0xFFD8E5D9,
                                      ),
                                      leading: SizedBox(
                                        width: 48,
                                        child: Text(
                                          '${index ~/ 2 + 1}. ${isWhiteMove ? 'White' : 'Black'}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      title: Text(
                                        widget.moves[index],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onTap: () => _showPly(index + 1),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.selected});

  final BoardTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.ink,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected ? theme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: ColoredBox(color: theme.surface)),
          Expanded(child: ColoredBox(color: theme.accent)),
          Expanded(child: ColoredBox(color: theme.surface)),
        ],
      ),
    );
  }
}
