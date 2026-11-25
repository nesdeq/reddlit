import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reddlit/widgets/sort_dialogs.dart';

Future<void> _open(WidgetTester tester, void Function(BuildContext) show) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => show(context),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

List<String> _labels(WidgetTester tester) => [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];

void main() {
  testWidgets('post sorts: labels in order; Top asks for a time window',
      (tester) async {
    final picked = <(String, String?)>[];
    await _open(
      tester,
      (context) => SortDialogs.showPostSortModal(
        context: context,
        currentSort: 'hot',
        currentTopTime: null,
        onSortChanged: (sort, {topTime}) => picked.add((sort, topTime)),
      ),
    );
    expect(_labels(tester), ['Hot', 'New', 'Rising', 'Controversial', 'Top']);

    await tester.tap(find.text('Top'));
    await tester.pumpAndSettle();
    expect(_labels(tester), [
      'Past Hour',
      'Past 24 Hours',
      'Past Week',
      'Past Month',
      'Past Year',
      'All Time',
    ]);
    await tester.tap(find.text('Past Week'));
    await tester.pumpAndSettle();
    expect(picked, [('top', 'week')]);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('post sorts: a plain sort reports without a time window',
      (tester) async {
    final picked = <(String, String?)>[];
    await _open(
      tester,
      (context) => SortDialogs.showPostSortModal(
        context: context,
        currentSort: 'hot',
        currentTopTime: null,
        onSortChanged: (sort, {topTime}) => picked.add((sort, topTime)),
      ),
    );
    await tester.tap(find.text('Rising'));
    await tester.pumpAndSettle();
    expect(picked, [('rising', null)]);
  });

  testWidgets('comment sorts: labels in order; the current one is checked',
      (tester) async {
    final picked = <String>[];
    await _open(
      tester,
      (context) => SortDialogs.showCommentSortModal(
        context: context,
        currentSort: 'new',
        onSortChanged: picked.add,
      ),
    );
    expect(_labels(tester), ['Best', 'Top', 'New', 'Controversial']);
    final checked = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where((tile) => tile.trailing != null)
        .map((tile) => (tile.title! as Text).data);
    expect(checked, ['New']);
    await tester.tap(find.text('Best'));
    await tester.pumpAndSettle();
    expect(picked, ['confidence']);
  });
}
