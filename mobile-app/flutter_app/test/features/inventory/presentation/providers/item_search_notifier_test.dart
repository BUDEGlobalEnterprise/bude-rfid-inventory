import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/inventory/domain/usecases/search_items_usecase.dart';
import 'package:bude_inventory/features/inventory/presentation/providers/item_search_notifier.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchUseCase extends Mock implements SearchItemsUseCase {}

class _FakeSearchParams extends Fake implements SearchItemsParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSearchParams());
  });

  late _MockSearchUseCase useCase;
  late ItemSearchNotifier notifier;

  setUp(() {
    useCase = _MockSearchUseCase();
    notifier = ItemSearchNotifier(useCase);
  });

  tearDown(() => notifier.dispose());

  test('starts in idle state', () {
    expect(notifier.state, isA<ItemSearchIdle>());
  });

  test('empty query resets to idle without calling use case', () async {
    notifier.onQueryChanged('   ');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(notifier.state, isA<ItemSearchIdle>());
    verifyNever(() => useCase(any()));
  });

  test('debounces rapid input — only the final query is searched', () async {
    when(() => useCase(any())).thenAnswer(
      (_) async => const Right<Failure, List<Item>>([
        Item(itemCode: 'A', itemName: 'A'),
      ]),
    );

    notifier.onQueryChanged('w');
    notifier.onQueryChanged('wi');
    notifier.onQueryChanged('wid');

    await Future<void>.delayed(const Duration(milliseconds: 500));

    final captured = verify(() => useCase(captureAny())).captured;
    expect(captured, hasLength(1));
    expect((captured.single as SearchItemsParams).query, 'wid');

    final state = notifier.state;
    expect(state, isA<ItemSearchResults>());
    expect((state as ItemSearchResults).query, 'wid');
    expect(state.items, hasLength(1));
  });

  test('maps failure to error state', () async {
    when(() => useCase(any())).thenAnswer(
      (_) async => const Left(ServerFailure('boom')),
    );

    notifier.onQueryChanged('q');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final state = notifier.state;
    expect(state, isA<ItemSearchError>());
    expect((state as ItemSearchError).message, 'boom');
  });
}
