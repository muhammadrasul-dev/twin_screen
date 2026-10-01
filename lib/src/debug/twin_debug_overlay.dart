import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/twin_resolver.dart';
import '../models/twin_enums.dart';
import '../models/twin_screen_data.dart';
import '../models/window_class.dart';
import '../widgets/twin_screen_scope.dart';
import 'twin_device_preset.dart';
import 'twin_simulator.dart';

/// Shows the fold, the segments and the screen state on top of the app, and
/// simulates foldable devices.
///
/// Place it inside [TwinScreenScope], above your app:
///
/// ```dart
/// void main() => runApp(
///   const TwinScreenScope(child: TwinDebugOverlay(child: MyApp())),
/// );
/// ```
///
/// A small button opens a draggable panel with the current mode, posture,
/// hinge angle, window class, size, platform and data source. The panel's
/// simulator renders the app at the logical size of a device preset (iPhone
/// Duo, Galaxy Z Fold, Galaxy Z Flip, Pixel Fold, Surface Duo, Xiaomi Mix
/// Flip) and fakes `MediaQuery` and the platform report, so every posture and
/// orientation can be tried without the hardware.
///
/// The overlay is off in release builds unless [enabled] is set.
class TwinDebugOverlay extends StatefulWidget {
  /// Creates a debug overlay.
  const TwinDebugOverlay({
    super.key,
    required this.child,
    this.enabled = !kReleaseMode,
    this.controller,
    this.presets = TwinDevicePreset.all,
    this.drawFeatures = true,
    this.showPanel = true,
  });

  /// The app.
  final Widget child;

  /// Whether the overlay does anything. Defaults to true in debug and profile
  /// builds and false in release builds. When false, [child] is returned
  /// unchanged.
  final bool enabled;

  /// Drives the simulator. When null the overlay creates its own, with the
  /// simulator off.
  final TwinSimulatorController? controller;

  /// The presets offered in the panel.
  final List<TwinDevicePreset> presets;

  /// Whether to draw segments, the hinge and cutouts over the app.
  final bool drawFeatures;

  /// Whether to show the panel button. Turn it off to drive the simulator
  /// from code only, for example in widget tests.
  final bool showPanel;

  @override
  State<TwinDebugOverlay> createState() => _TwinDebugOverlayState();
}

class _TwinDebugOverlayState extends State<TwinDebugOverlay> {
  final GlobalKey _appKey = GlobalKey(debugLabel: 'twin_screen.app');
  TwinSimulatorController? _ownController;
  bool _panelOpen = false;
  bool _drawFeatures = true;
  Offset? _panelOffset;

  TwinSimulatorController get _controller =>
      widget.controller ?? (_ownController ??= TwinSimulatorController());

  @override
  void initState() {
    super.initState();
    _drawFeatures = widget.drawFeatures;
    _controller.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(TwinDebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawFeatures != widget.drawFeatures) _drawFeatures = widget.drawFeatures;
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_handleChange);
      _controller.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _ownController?.dispose();
    super.dispose();
  }

  void _handleChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final Widget app = KeyedSubtree(key: _appKey, child: widget.child);
    if (!widget.enabled) return app;

    final TwinSimulatorController controller = _controller;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final WindowClassBreakpoints breakpoints = TwinScreen.breakpointsOf(context);
    final TextDirection direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

    final TwinScreenData data;
    final Widget body;
    final String platform;
    if (controller.enabled) {
      final TwinSimulatedScreen screen = controller.screen;
      data = TwinResolver.resolve(
        size: screen.size,
        flutterFeatures: const <DisplayFeature>[],
        platform: screen.platform.copyWith(displayFeatures: screen.displayFeatures),
        breakpoints: breakpoints,
      );
      platform = '${controller.preset.platform.name} (simulated)';
      body = _SimulatedDevice(
        screen: screen,
        mediaQuery: mediaQuery,
        breakpoints: breakpoints,
        drawFeatures: _drawFeatures,
        child: app,
      );
    } else {
      data = TwinScreen.of(context);
      platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      body = _drawFeatures
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                app,
                IgnorePointer(child: CustomPaint(painter: _FeaturePainter(data))),
              ],
            )
          : app;
    }

    return Directionality(
      textDirection: direction,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          body,
          // The panel gets its own Overlay for the Slider. Taps outside the
          // panel fall through to the app.
          if (widget.showPanel)
            Positioned.fill(
              child: Overlay.wrap(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[_buildPanel(mediaQuery, controller, data, platform)],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    MediaQueryData mediaQuery,
    TwinSimulatorController controller,
    TwinScreenData data,
    String platform,
  ) {
    final Size screen = mediaQuery.size;
    final Size panelSize = _panelOpen
        ? Size(math.min(320, screen.width - 16), math.min(560, screen.height - 16))
        : const Size(44, 44);
    final Offset fallback = Offset(
      screen.width - panelSize.width - 12,
      math.max(mediaQuery.padding.top + 8, screen.height * 0.25),
    );
    final Offset raw = _panelOffset ?? fallback;
    final Offset offset = Offset(
      raw.dx.clamp(0, math.max(0, screen.width - panelSize.width)).toDouble(),
      raw.dy.clamp(0, math.max(0, screen.height - panelSize.height)).toDouble(),
    );

    void drag(DragUpdateDetails details) => setState(() => _panelOffset = offset + details.delta);

    final Widget content = _panelOpen
        ? _Panel(
            size: panelSize,
            data: data,
            platform: platform,
            controller: controller,
            presets: widget.presets,
            drawFeatures: _drawFeatures,
            onDrawFeaturesChanged: (bool value) => setState(() => _drawFeatures = value),
            onClose: () => setState(() => _panelOpen = false),
            onDrag: drag,
          )
        : _PanelButton(
            simulating: controller.enabled,
            onTap: () => setState(() => _panelOpen = true),
            onDrag: drag,
          );

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: panelSize.width,
      height: _panelOpen ? null : panelSize.height,
      child: _PanelTheme(child: content),
    );
  }
}

/// Renders the app at the simulated device size, scaled to fit.
class _SimulatedDevice extends StatelessWidget {
  const _SimulatedDevice({
    required this.screen,
    required this.mediaQuery,
    required this.breakpoints,
    required this.drawFeatures,
    required this.child,
  });

  final TwinSimulatedScreen screen;
  final MediaQueryData mediaQuery;
  final WindowClassBreakpoints breakpoints;
  final bool drawFeatures;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData simulated = mediaQuery.copyWith(
      size: screen.size,
      padding: screen.padding,
      viewPadding: screen.padding,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
      displayFeatures: const <DisplayFeature>[],
    );
    return ColoredBox(
      color: const Color(0xFF202124),
      child: Padding(
        padding: mediaQuery.padding + const EdgeInsets.all(12),
        child: Center(
          child: FittedBox(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF5F6368), width: 8),
                borderRadius: BorderRadius.circular(28),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox.fromSize(
                  size: screen.size,
                  child: MediaQuery(
                    data: simulated,
                    child: TwinScreenScope(
                      breakpoints: breakpoints,
                      platformOverride: screen.platform.copyWith(
                        displayFeatures: screen.displayFeatures,
                      ),
                      child: drawFeatures ? _FeatureLayer(child: child) : child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the features of the nearest scope over [child].
class _FeatureLayer extends StatelessWidget {
  const _FeatureLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: <Widget>[
        child,
        IgnorePointer(child: CustomPaint(painter: _FeaturePainter(TwinScreen.of(context)))),
      ],
    );
  }
}

class _FeaturePainter extends CustomPainter {
  _FeaturePainter(this.data);

  final TwinScreenData data;

  static const Color _start = Color(0xFF1E88E5);
  static const Color _end = Color(0xFF43A047);
  static const Color _hinge = Color(0xFFE53935);
  static const Color _cutout = Color(0xFFFB8C00);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isSpanned) {
      _segment(canvas, data.startSegment, _start, 'start');
      _segment(canvas, data.endSegment, _end, 'end');
    }
    final Rect? hinge = data.hinge?.bounds;
    if (hinge != null) {
      if (hinge.shortestSide > 0) {
        canvas.drawRect(hinge, Paint()..color = _hinge.withValues(alpha: 0.55));
      }
      final Paint line = Paint()
        ..color = _hinge
        ..strokeWidth = 2;
      final bool vertical = hinge.height >= hinge.width;
      final Offset a = vertical
          ? Offset(hinge.center.dx, hinge.top)
          : Offset(hinge.left, hinge.center.dy);
      final Offset b = vertical
          ? Offset(hinge.center.dx, hinge.bottom)
          : Offset(hinge.right, hinge.center.dy);
      _dashed(canvas, a, b, line);
    }
    for (final DisplayFeature feature in data.displayFeatures) {
      if (feature.type != DisplayFeatureType.cutout) continue;
      canvas.drawRect(feature.bounds, Paint()..color = _cutout.withValues(alpha: 0.6));
    }
  }

  void _segment(Canvas canvas, Rect rect, Color color, String label) {
    canvas.drawRect(
      rect.deflate(1.5),
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: ' $label ',
        style: TextStyle(fontSize: 10, color: const Color(0xFFFFFFFF), backgroundColor: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, rect.bottomLeft + Offset(6, -text.height - 6));
  }

  static void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final double length = (b - a).distance;
    if (length == 0) return;
    final Offset step = (b - a) / length;
    for (double t = 0; t < length; t += 10) {
      canvas.drawLine(a + step * t, a + step * math.min(t + 6, length), paint);
    }
  }

  @override
  bool shouldRepaint(_FeaturePainter oldDelegate) => oldDelegate.data != data;
}

/// Gives the panel Material widgets what they need above the app's
/// `MaterialApp`: localizations, a theme and a [Material].
class _PanelTheme extends StatelessWidget {
  const _PanelTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Localizations(
      locale: const Locale('en'),
      delegates: const <LocalizationsDelegate<Object>>[
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7C4DFF),
          visualDensity: VisualDensity.compact,
        ),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.simulating, required this.onTap, required this.onDrag});

  final bool simulating;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onDrag;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanUpdate: onDrag,
      child: Material(
        key: const ValueKey<String>('twin_debug_overlay.button'),
        color: simulating ? colors.primary : colors.surfaceContainerHighest,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(
              Icons.devices_fold,
              size: 22,
              color: simulating ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.size,
    required this.data,
    required this.platform,
    required this.controller,
    required this.presets,
    required this.drawFeatures,
    required this.onDrawFeaturesChanged,
    required this.onClose,
    required this.onDrag,
  });

  final Size size;
  final TwinScreenData data;
  final String platform;
  final TwinSimulatorController controller;
  final List<TwinDevicePreset> presets;
  final bool drawFeatures;
  final ValueChanged<bool> onDrawFeaturesChanged;
  final VoidCallback onClose;
  final GestureDragUpdateCallback onDrag;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle label = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bool simulating = controller.enabled;
    final TwinDevicePreset preset = controller.preset;

    return Material(
      key: const ValueKey<String>('twin_debug_overlay.panel'),
      color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.96),
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GestureDetector(
              onPanUpdate: onDrag,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.drag_indicator, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text('twin_screen', style: theme.textTheme.titleSmall)),
                    IconButton(
                      key: const ValueKey<String>('twin_debug_overlay.close'),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _InfoTable(data: data, platform: platform),
                    const SizedBox(height: 4),
                    _SwitchRow(
                      label: 'Draw segments and hinge',
                      value: drawFeatures,
                      onChanged: onDrawFeaturesChanged,
                    ),
                    const Divider(),
                    _SwitchRow(
                      key: const ValueKey<String>('twin_debug_overlay.simulate'),
                      label: 'Fold simulator',
                      value: simulating,
                      onChanged: (bool value) => controller.enabled = value,
                    ),
                    if (simulating) ...<Widget>[
                      Text('Device', style: label),
                      _Choices<TwinDevicePreset>(
                        values: presets,
                        selected: preset,
                        labelOf: (TwinDevicePreset p) => p.name,
                        onSelected: (TwinDevicePreset p) => controller.preset = p,
                      ),
                      Text('Posture', style: label),
                      _Choices<TwinPosture>(
                        values: <TwinPosture>[
                          if (preset.hasCover) TwinPosture.closed,
                          TwinPosture.halfOpened,
                          TwinPosture.flat,
                        ],
                        selected: controller.posture,
                        labelOf: _postureLabel,
                        onSelected: (TwinPosture p) => controller.posture = p,
                      ),
                      Text('Hinge angle ${controller.hingeAngle.round()}°', style: label),
                      Slider(
                        value: controller.hingeAngle,
                        max: 180,
                        onChanged: (double angle) => controller.hingeAngle = angle,
                      ),
                      Text('Orientation', style: label),
                      _Choices<Orientation>(
                        values: Orientation.values,
                        selected: controller.orientation,
                        labelOf: (Orientation o) => o.name,
                        onSelected: (Orientation o) => controller.orientation = o,
                      ),
                      if (controller.posture != TwinPosture.closed) ...<Widget>[
                        Text('App window', style: label),
                        _Choices<TwinSimulatedSpan>(
                          values: TwinSimulatedSpan.values,
                          selected: controller.span,
                          labelOf: _spanLabel,
                          onSelected: (TwinSimulatedSpan s) => controller.span = s,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _postureLabel(TwinPosture posture) => switch (posture) {
    TwinPosture.closed => 'closed',
    TwinPosture.halfOpened => 'half-open',
    TwinPosture.flat => 'flat',
    TwinPosture.unknown => 'unknown',
  };

  static String _spanLabel(TwinSimulatedSpan span) => switch (span) {
    TwinSimulatedSpan.both => 'both sides',
    TwinSimulatedSpan.start => 'start only',
    TwinSimulatedSpan.end => 'end only',
  };
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.data, required this.platform});

  final TwinScreenData data;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle key = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final TextStyle value = theme.textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600);
    final double? angle = data.hingeAngle;
    final Map<String, String> rows = <String, String>{
      'mode': data.mode.name,
      'device': data.deviceType.name,
      'posture': data.posture.name,
      'hinge angle': angle == null ? '–' : '${angle.round()}°',
      'spanned': data.isSpanned ? 'yes (${data.hinge!.axis.name} hinge)' : 'no',
      'window class': '${data.windowClass.width.name} × ${data.windowClass.height.name}',
      'size': '${_dp(data.size.width)} × ${_dp(data.size.height)} dp',
      'platform': platform,
      'source': data.source.name,
    };
    return Column(
      key: const ValueKey<String>('twin_debug_overlay.info'),
      children: <Widget>[
        for (final MapEntry<String, String> row in rows.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              children: <Widget>[
                SizedBox(width: 96, child: Text(row.key, style: key)),
                Expanded(child: Text(row.value, style: value)),
              ],
            ),
          ),
      ],
    );
  }

  static String _dp(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final T value in values)
            Material(
              color: value == selected ? colors.primary : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey<String>('twin_debug_overlay.choice.${labelOf(value)}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    labelOf(value),
                    style: TextStyle(
                      fontSize: 12,
                      color: value == selected ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
