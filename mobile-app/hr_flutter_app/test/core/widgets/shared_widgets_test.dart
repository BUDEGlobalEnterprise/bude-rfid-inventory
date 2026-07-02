import 'package:bude_hr/core/widgets/async_states.dart';
import 'package:bude_hr/core/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmDialog returns true on confirm and false on cancel',
      (tester) async {
    late Future<bool> pending;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => pending = confirmDialog(
                context,
                title: 'Discard?',
                message: 'Are you sure?',
                confirmLabel: 'Discard',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(await pending, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await pending, isFalse);
  });

  testWidgets('ErrorRetry shows the message and fires onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorRetry(
            message: 'Boom',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Boom'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
