import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:twin_screen/twin_screen.dart';

/// A demo shown in the example app.
class Demo {
  const Demo._(this.title, this.subtitle, this.icon, this.builder);

  /// The demo's name.
  final String title;

  /// One line about it.
  final String subtitle;

  /// The list icon.
  final IconData icon;

  /// Builds the demo body.
  final WidgetBuilder builder;

  /// Every demo, in list order.
  static final List<Demo> all = <Demo>[
    Demo._(
      'Screen state',
      'Mode, posture, hinge, segments',
      Icons.info_outline,
      (_) => const StateDemo(),
    ),
    Demo._(
      'TwinPane',
      'Two panes split at the fold',
      Icons.vertical_split_outlined,
      (_) => const PaneDemo(),
    ),
    Demo._(
      'Fold-aware dialog',
      'Opens on one side of the fold',
      Icons.chat_bubble_outline,
      (_) => const DialogDemo(),
    ),
    Demo._(
      'Fold-aware bottom sheet',
      'Rises on one side of the fold',
      Icons.vertical_align_top,
      (_) => const BottomSheetDemo(),
    ),
    Demo._(
      'Window class',
      'compact / medium / expanded',
      Icons.aspect_ratio,
      (_) => const WindowClassDemo(),
    ),
    Demo._(
      "Flutter's own widgets",
      'DisplayFeatureSubScreen, showDialog',
      Icons.flutter_dash,
      (_) => const FlutterWidgetsDemo(),
    ),
  ];
}

/// Formats [r] as left, top, right, bottom. `Rect.toString` is shortened in
/// profile and release builds.
String _rect(Rect r) =>
    '(${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)})';

/// A coloured strip with the current mode, shown at the top of the list.
class ModeBanner extends StatelessWidget {
  /// Creates the banner.
  const ModeBanner({super.key, required this.data});

  /// The screen data to show.
  final TwinScreenData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String text = switch (data.mode) {
      TwinScreenMode.standard => 'Ordinary screen',
      TwinScreenMode.cover => 'Folded: cover screen',
      TwinScreenMode.singlePane => 'Open, app on one side',
      TwinScreenMode.dualPane => 'Open flat, both sides',
      TwinScreenMode.book => 'Half-open like a book',
      TwinScreenMode.tabletop => 'Half-open like a laptop',
    };
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.devices_fold, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${data.mode.name} · $text',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lists every field of [TwinScreenData] and the live hinge angle stream.
class StateDemo extends StatelessWidget {
  /// Creates the demo.
  const StateDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final TwinScreenData data = TwinScreen.of(context);
    final List<(String, String)> rows = <(String, String)>[
      ('mode', data.mode.name),
      ('deviceType', data.deviceType.name),
      ('posture', data.posture.name),
      ('isSpanned', '${data.isSpanned}'),
      (
        'hingeAngle',
        data.hingeAngle == null
            ? 'null'
            : '${data.hingeAngle!.toStringAsFixed(1)}°',
      ),
      (
        'hinge',
        data.hinge == null
            ? 'null'
            : '${data.hinge!.axis.name}, ${_rect(data.hinge!.bounds)}',
      ),
      ('separating', '${data.hinge?.isSeparating ?? false}'),
      ('occludesContent', '${data.hinge?.occludesContent ?? false}'),
      ('segments', data.segments.map(_rect).join('\n')),
      (
        'windowClass',
        '${data.windowClass.width.name} × ${data.windowClass.height.name}',
      ),
      (
        'size',
        '${data.size.width.toStringAsFixed(1)} × ${data.size.height.toStringAsFixed(1)}',
      ),
      ('source', data.source.name),
      (
        'displayFeatures',
        data.displayFeatures.isEmpty
            ? 'none'
            : data.displayFeatures
                  .map(
                    (DisplayFeature f) =>
                        '${f.type.name}, ${f.state.name}, ${_rect(f.bounds)}',
                  )
                  .join('\n'),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final (String key, String value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 130,
                  child: Text(
                    key,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(child: SelectableText(value)),
              ],
            ),
          ),
        const Divider(height: 32),
        StreamBuilder<double?>(
          stream: TwinScreen.hingeAngleStreamOf(context),
          builder: (BuildContext context, AsyncSnapshot<double?> snapshot) {
            final double? angle = snapshot.data;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.screen_rotation_alt),
              title: const Text('TwinScreen.hingeAngleStreamOf'),
              subtitle: Text(
                angle == null ? 'no hinge sensor' : '${angle.round()}°',
              ),
              trailing: angle == null
                  ? null
                  : SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: (angle / 180).clamp(0, 1),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

/// A nested [TwinPane] with every fallback to pick from.
class PaneDemo extends StatefulWidget {
  /// Creates the demo.
  const PaneDemo({super.key});

  @override
  State<PaneDemo> createState() => _PaneDemoState();
}

class _PaneDemoState extends State<PaneDemo> {
  TwinPaneFallback _fallback = TwinPaneFallback.windowClass;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final TwinPaneFallback fallback in TwinPaneFallback.values)
                ChoiceChip(
                  label: Text(fallback.name),
                  selected: fallback == _fallback,
                  onSelected: (_) => setState(() => _fallback = fallback),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'The fallback applies when no hinge separates the window. A '
            'separating hinge always splits the panes exactly at the hinge.',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TwinPane(
            fallback: _fallback,
            start: const _PaneBox(label: 'start', color: Colors.teal),
            end: const _PaneBox(label: 'end', color: Colors.amber),
          ),
        ),
      ],
    );
  }
}

class _PaneBox extends StatelessWidget {
  const _PaneBox({required this.label, required this.color});

  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.shade100,
      child: SafeArea(
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 28, color: color.shade900),
          ),
        ),
      ),
    );
  }
}

/// Opens [showFoldAwareDialog] in every placement mode.
class DialogDemo extends StatelessWidget {
  /// Creates the demo.
  const DialogDemo({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> open({
      Offset? anchor,
      TwinPaneSide side = TwinPaneSide.start,
      bool spanning = false,
      required String how,
    }) {
      return showFoldAwareDialog<void>(
        context: context,
        anchorPoint: anchor,
        preferredSide: side,
        allowSpanning: spanning,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Fold-aware dialog'),
          content: Text(how),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'On a spanned window the dialog stays on one side of the fold.',
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (BuildContext context) => GestureDetector(
            onTapDown: (TapDownDetails details) => open(
              anchor: details.globalPosition,
              how: 'anchorPoint: the side you tapped',
            ),
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Tap here: opens on this side (anchorPoint)'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => open(how: 'preferredSide: start'),
          child: const Text('preferredSide: start'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () =>
              open(side: TwinPaneSide.end, how: 'preferredSide: end'),
          child: const Text('preferredSide: end'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () =>
              open(spanning: true, how: 'allowSpanning: covers both sides'),
          child: const Text('allowSpanning: true'),
        ),
      ],
    );
  }
}

/// Opens [showFoldAwareBottomSheet] in every placement mode.
class BottomSheetDemo extends StatelessWidget {
  /// Creates the demo.
  const BottomSheetDemo({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> open({
      Offset? anchor,
      TwinPaneSide side = TwinPaneSide.start,
      bool spanning = false,
      required String how,
    }) {
      return showFoldAwareBottomSheet<void>(
        context: context,
        anchorPoint: anchor,
        preferredSide: side,
        allowSpanning: spanning,
        showDragHandle: true,
        builder: (BuildContext context) =>
            SizedBox(height: 200, child: Center(child: Text(how))),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'On a spanned window the sheet stays on one side of the fold.',
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTapDown: (TapDownDetails details) => open(
            anchor: details.globalPosition,
            how: 'anchorPoint: the side you tapped',
          ),
          child: const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Tap here: rises on this side (anchorPoint)'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => open(how: 'preferredSide: start'),
          child: const Text('preferredSide: start'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () =>
              open(side: TwinPaneSide.end, how: 'preferredSide: end'),
          child: const Text('preferredSide: end'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () =>
              open(spanning: true, how: 'allowSpanning: covers both sides'),
          child: const Text('allowSpanning: true'),
        ),
      ],
    );
  }
}

/// Shows which window class layout is active.
class WindowClassDemo extends StatelessWidget {
  /// Creates the demo.
  const WindowClassDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final WindowClass windowClass = WindowClass.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Window: ${windowClass.width.name} wide, ${windowClass.height.name} tall',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: WindowClassBuilder(
            compact: (_) => const _ClassCard(
              'compact',
              'One column, bottom navigation',
              Icons.smartphone,
            ),
            medium: (_) => const _ClassCard(
              'medium',
              'Two columns, navigation rail',
              Icons.tablet_android,
            ),
            expanded: (_) => const _ClassCard(
              'expanded',
              'List-detail, navigation drawer',
              Icons.desktop_windows,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Width: compact < 600, medium 600–839, expanded ≥ 840.\n'
          'Height: compact < 480, medium 480–899, expanded ≥ 900.\n'
          'Change them with TwinScreenScope(breakpoints: ...).',
        ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard(this.name, this.description, this.icon);

  final String name;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: ListTile(
          leading: Icon(icon, size: 40),
          title: Text('WindowClassBuilder → $name'),
          subtitle: Text(description),
        ),
      ),
    );
  }
}

/// Shows that Flutter's own fold-aware widgets see the fold that
/// [TwinScreenScope] injects on iOS and web.
class FlutterWidgetsDemo extends StatelessWidget {
  /// Creates the demo.
  const FlutterWidgetsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DisplayFeature> features = MediaQuery.displayFeaturesOf(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'MediaQuery.displayFeatures (${features.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final DisplayFeature feature in features)
          Text(
            '${feature.type.name} · ${feature.state.name} · ${_rect(feature.bounds)}',
          ),
        if (features.isEmpty) const Text('none: no fold crosses this pane'),
        const SizedBox(height: 16),
        const Text(
          'TwinPane gives each pane only the features inside it, so open this '
          'demo full screen (on a compact window) to see the fold here. On iOS '
          'and web the fold comes from twin_screen; on Android from Flutter.',
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (BuildContext context) => GestureDetector(
            onTapDown: (TapDownDetails details) => showDialog<void>(
              context: context,
              anchorPoint: details.globalPosition,
              builder: (BuildContext context) => const AlertDialog(
                title: Text('Flutter showDialog'),
                content: Text(
                  'Plain showDialog(anchorPoint:) also avoids the fold.',
                ),
              ),
            ),
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Tap: Flutter showDialog(anchorPoint: tap)'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
