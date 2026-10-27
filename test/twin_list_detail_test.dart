import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

const Key listKey = Key('list');
const Key detailKey = Key('detail');
const Key placeholderKey = Key('placeholder');

class Host extends StatefulWidget {
  const Host({super.key, this.initialSelection = false});

  final bool initialSelection;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late bool selected = widget.initialSelection;
  bool? splitSeenByList;

  void select(bool value) => setState(() => selected = value);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TwinListDetail(
        list: Builder(
          builder: (BuildContext context) {
            splitSeenByList = TwinListDetail.isSplitOf(context);
            return const SizedBox.expand(key: listKey);
          },
        ),
        detail: selected ? const SizedBox.expand(key: detailKey) : null,
        placeholder: const SizedBox.expand(key: placeholderKey),
        onDetailClosed: () => select(false),
      ),
    );
  }
}

Future<void> pump(WidgetTester tester, Size size, TwinPlatformState state, Widget child) async {
  setWindowSize(tester, size);
  await tester.pumpWidget(TwinScreenScope(platformOverride: state, child: child));
  await tester.pump();
}

void main() {
  testWidgets('splits at the fold, with the placeholder until something is selected', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Size(800, 600), bookState(), const Host());
    expect(tester.getRect(find.byKey(listKey)), const Rect.fromLTRB(0, 0, 400, 600));
    expect(tester.getRect(find.byKey(placeholderKey)), const Rect.fromLTRB(400, 0, 800, 600));
    expect(find.byKey(detailKey), findsNothing);

    tester.state<HostState>(find.byType(Host)).select(true);
    await tester.pump();
    expect(tester.getRect(find.byKey(detailKey)), const Rect.fromLTRB(400, 0, 800, 600));
    expect(find.byKey(placeholderKey), findsNothing);
  });

  testWidgets('on a phone the list shows alone, then the detail replaces it', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Size(400, 800), TwinPlatformState.fallback, const Host());
    expect(tester.getRect(find.byKey(listKey)), const Rect.fromLTWH(0, 0, 400, 800));
    expect(find.byKey(placeholderKey), findsNothing);
    expect(tester.state<HostState>(find.byType(Host)).splitSeenByList, isFalse);

    tester.state<HostState>(find.byType(Host)).select(true);
    await tester.pump();
    expect(tester.getRect(find.byKey(detailKey)), const Rect.fromLTWH(0, 0, 400, 800));
    expect(find.byKey(listKey), findsNothing);
    expect(find.byKey(listKey, skipOffstage: false), findsOneWidget);
  });

  testWidgets('the back gesture closes the detail when stacked', (WidgetTester tester) async {
    await pump(
      tester,
      const Size(400, 800),
      TwinPlatformState.fallback,
      const MaterialApp(home: Host(initialSelection: true)),
    );
    expect(find.byKey(detailKey), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(detailKey), findsNothing);
    expect(find.byKey(listKey), findsOneWidget);
  });

  testWidgets('the list keeps its state while the detail is shown', (WidgetTester tester) async {
    int created = 0;
    bool selected = false;
    late StateSetter update;
    await pump(
      tester,
      const Size(400, 800),
      TwinPlatformState.fallback,
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            update = setState;
            return TwinListDetail(
              list: StateProbe(onCreate: () => created++),
              detail: selected ? const SizedBox.expand(key: detailKey) : null,
            );
          },
        ),
      ),
    );
    update(() => selected = true);
    await tester.pump();
    update(() => selected = false);
    await tester.pump();
    expect(created, 1);
  });

  testWidgets('isSplitOf is true when side by side', (WidgetTester tester) async {
    await pump(tester, const Size(800, 600), bookState(), const Host());
    expect(tester.state<HostState>(find.byType(Host)).splitSeenByList, isTrue);
  });
}
