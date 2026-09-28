import 'package:flutter_test/flutter_test.dart';

import 'package:app1/main.dart';

void main() {
  testWidgets('shows a fresh local chess game', (tester) async {
    await tester.pumpWidget(const ChessGameApp());

    expect(find.text('CHESS ROOM'), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Move history'), findsOneWidget);
    expect(find.text('Reset game'), findsOneWidget);
    expect(find.text('Undo move'), findsOneWidget);
  });

  testWidgets('offers local computer and online modes', (tester) async {
    await tester.pumpWidget(const ChessGameApp());

    await tester.tap(find.byTooltip('Choose game mode'));
    await tester.pumpAndSettle();

    expect(find.text('Play computer'), findsOneWidget);
    expect(find.text('Online multiplayer'), findsOneWidget);
  });
}
