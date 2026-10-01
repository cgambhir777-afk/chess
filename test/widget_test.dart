import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:app1/main.dart';

void main() {
  testWidgets('shows game modes and a computer difficulty control', (
    tester,
  ) async {
    await tester.pumpWidget(const ChessGameApp());

    expect(find.text('CHESS ROOM'), findsOneWidget);
    expect(find.text('Play computer'), findsOneWidget);
    expect(find.text('Play a friend'), findsOneWidget);
    expect(find.text('Online multiplayer'), findsOneWidget);
    expect(find.text('Computer difficulty'), findsOneWidget);
  });

  testWidgets('starts a computer game from the home screen', (tester) async {
    await tester.pumpWidget(const ChessGameApp());

    await tester.tap(find.text('Play computer'));
    await tester.pumpAndSettle();

    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Computer'), findsOneWidget);
    expect(find.text('Move history'), findsOneWidget);
  });

  testWidgets('reviews moves by selecting a ply', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameReviewPage(
          positions: const [
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
            'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          ],
          moves: const ['e4', 'e5'],
          result: 'Draw by stalemate',
          boardTheme: BoardTheme.forest,
        ),
      ),
    );

    expect(find.text('Match review'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next move'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('e5'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
