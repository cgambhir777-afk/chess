import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:chess/chess.dart' as chess;

void main() => runApp(const ChessGameApp());

enum GameMode { local, computer }

enum BoardTheme {
  forest('Forest', BoardColor.green, Color(0xFF193A35), Color(0xFFE5F0E8), Color(0xFFB8D7C2)),
  walnut('Walnut', BoardColor.brown, Color(0xFF4A2B20), Color(0xFFF5E8D6), Color(0xFFDDBA8C)),
  midnight('Midnight', BoardColor.darkBrown, Color(0xFF1B2034), Color(0xFFE7E9F6), Color(0xFF9AA8D6)),
  ember('Ember', BoardColor.orange, Color(0xFF54261C), Color(0xFFFFE7D2), Color(0xFFE9A06B));

  const BoardTheme(this.label, this.boardColor, this.ink, this.surface, this.accent);

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
  final ComputerPlayer _computer = ComputerPlayer();
  GameMode _gameMode = GameMode.local;
  BoardTheme _boardTheme = BoardTheme.forest;
  String? _selectedSquare;
  bool _resultDialogShown = false;
  bool _computerThinking = false;

  Chess get _game => _controller.game;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleMove() {
    setState(() => _selectedSquare = null);
    if (_finishGameIfNeeded()) return;
    if (_gameMode == GameMode.computer && _game.turn == Chess.BLACK) {
      _playComputerMove();
    }
  }

  void _resetGame() {
    _controller.resetBoard();
    setState(() {
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

    final move = _computer.chooseMove(_game);
    if (move != null) {
      final nextGame = _game.copy();
      nextGame.move({
        'from': move.fromAlgebraic,
        'to': move.toAlgebraic,
        if (move.promotion != null)
          'promotion': _promotionName(move.promotion!),
      });
      _replaceController(nextGame);
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
              subtitle: Text(_gameMode == GameMode.local ? 'Selected' : 'Pass and play locally'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, GameMode.computer),
            child: const ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('Play computer'),
              subtitle: Text('You play White against the computer'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showOnlineInfo();
            },
            child: const ListTile(
              leading: Icon(Icons.cloud_outlined),
              title: Text('Online multiplayer'),
              subtitle: Text('Requires a matchmaking server'),
            ),
          ),
        ],
      ),
    );
    if (selectedMode == null || selectedMode == _gameMode) return;
    _gameMode = selectedMode;
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
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
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
              const Text('Choose your table', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Every palette changes the board and the room around it.'),
              const SizedBox(height: 16),
              for (final theme in BoardTheme.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _ThemeSwatch(theme: theme, selected: theme == _boardTheme),
                  title: Text(theme.label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    return Scaffold(
      backgroundColor: Color.lerp(_boardTheme.surface, const Color(0xFFF4F1EA), 0.34),
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
                              onTapUp: (details) => _handleBoardTap(
                                details,
                                boardSize - 16,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 650),
                                switchInCurve: Curves.easeOutBack,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(scale: animation, child: child),
                                ),
                                child: ChessBoard(
                                  key: ValueKey(_boardTheme),
                                  controller: _controller,
                                  size: boardSize - 16,
                                  boardColor: _boardTheme.boardColor,
                                  boardOrientation: PlayerColor.white,
                                  enableUserMoves: !_game.game_over &&
                                      !_computerThinking &&
                                      (_gameMode == GameMode.local ||
                                          _game.turn == Chess.WHITE),
                                  onMove: _handleMove,
                                ),
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
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
              Icon(
                Icons.circle,
                size: 10,
                color: isWhiteTurn
                    ? const Color(0xFFC5A35A)
                    : const Color(0xFFE9E4D9),
              ),
              const SizedBox(width: 9),
              Text(
                _game.game_over
                    ? 'Game complete'
                    : _computerThinking
                        ? 'Computer is thinking'
                        : _turnLabel,
                style: TextStyle(
                  color: isWhiteTurn
                      ? const Color(0xFF343A38)
                      : const Color(0xFFF7F3EA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_game.in_check && !_game.game_over) ...[
                const SizedBox(width: 8),
                const Text(
                  'CHECK',
                  style: TextStyle(
                    color: Color(0xFFB7684A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            key: ValueKey('${_game.history.length}-${_game.turn}-$_computerThinking'),
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
                style: TextStyle(
                  color: _boardTheme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayer(String name, String subtitle, bool active, bool isWhite) {
    final captured = _capturedPieces(isWhite ? Chess.BLACK : Chess.WHITE);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
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

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.selected});

  final BoardTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
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
