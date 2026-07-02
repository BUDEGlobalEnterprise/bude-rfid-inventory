import 'package:bude_hr/core/widgets/async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LoadingSkeleton renders placeholder cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingSkeleton())),
    );

    expect(find.byType(Card), findsWidgets);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('LoadingSkeleton displays in Material3', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: LoadingSkeleton()),
      ),
    );

    expect(find.byType(LoadingSkeleton), findsOneWidget);
  });

  testWidgets('LoadingSkeleton renders action card placeholders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingSkeleton())),
    );

    final containers = find.byType(Container);
    expect(containers, findsWidgets);
  });
}
