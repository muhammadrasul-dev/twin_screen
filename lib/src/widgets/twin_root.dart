import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Marks the origin of the coordinate space that `MediaQuery.displayFeatures`
/// uses. Inserted by `TwinScreenScope` directly around its child.
class TwinRoot extends SingleChildRenderObjectWidget {
  /// Creates a root marker.
  const TwinRoot({super.key, super.child});

  @override
  RenderTwinRoot createRenderObject(BuildContext context) => RenderTwinRoot();
}

/// The render object behind [TwinRoot].
class RenderTwinRoot extends RenderProxyBox {
  /// Converts a global position (for example `TapDownDetails.globalPosition`)
  /// into this root's coordinate space. Handles the fold simulator's scaling.
  Offset globalToRoot(Offset global) => attached ? globalToLocal(global) : global;
}

/// The nearest [RenderTwinRoot] above [node], or null.
RenderTwinRoot? findTwinRoot(RenderObject node) {
  RenderObject? current = node.parent;
  while (current != null) {
    if (current is RenderTwinRoot) return current;
    current = current.parent;
  }
  return null;
}

/// Where [node] sits relative to the nearest [RenderTwinRoot], using layout
/// offsets only.
///
/// Paint transforms are ignored on purpose: during a page transition the
/// route slides or scales, but its layout should stay aligned to the fold as
/// if it were at rest.
Offset layoutOffsetToRoot(RenderObject node) {
  Offset offset = Offset.zero;
  RenderObject child = node;
  RenderObject? parent = node.parent;
  while (parent != null && child is! RenderTwinRoot) {
    final ParentData? data = child.parentData;
    if (data is BoxParentData) {
      offset += data.offset;
    } else if (data is SliverPhysicalParentData) {
      offset += data.paintOffset;
    } else {
      final Matrix4 transform = Matrix4.identity();
      parent.applyPaintTransform(child, transform);
      offset += MatrixUtils.getAsTranslation(transform) ?? Offset.zero;
    }
    child = parent;
    parent = parent.parent;
  }
  return offset;
}

/// Signature for [RootRegionBuilder.builder].
///
/// [region] is the rectangle this widget occupies in the root coordinate
/// space. [root] converts global positions into that space.
typedef RootRegionWidgetBuilder =
    Widget Function(BuildContext context, Rect region, RenderTwinRoot? root);

/// Builds its child with the rectangle it occupies in the coordinate space of
/// the nearest `TwinScreenScope`, so it can be compared with display
/// features.
///
/// The position is measured after layout. If it moved, the widget rebuilds on
/// the next frame.
class RootRegionBuilder extends StatefulWidget {
  /// Creates a region builder.
  const RootRegionBuilder({super.key, required this.builder});

  /// Builds the child.
  final RootRegionWidgetBuilder builder;

  @override
  State<RootRegionBuilder> createState() => _RootRegionBuilderState();
}

class _RootRegionBuilderState extends State<RootRegionBuilder> {
  Offset _origin = Offset.zero;
  RenderTwinRoot? _root;

  void _handleMeasured(Offset origin, RenderTwinRoot? root) {
    if (!mounted || (origin == _origin && root == _root)) return;
    setState(() {
      _origin = origin;
      _root = root;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _OriginProbe(
      onMeasured: _handleMeasured,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          assert(
            constraints.hasBoundedWidth && constraints.hasBoundedHeight,
            'twin_screen fold-aware widgets need bounded constraints. Place them '
            'where they get a finite size, for example as a Scaffold body.',
          );
          return widget.builder(context, _origin & constraints.biggest, _root);
        },
      ),
    );
  }
}

typedef _MeasuredCallback = void Function(Offset origin, RenderTwinRoot? root);

class _OriginProbe extends SingleChildRenderObjectWidget {
  const _OriginProbe({required this.onMeasured, super.child});

  final _MeasuredCallback onMeasured;

  @override
  _RenderOriginProbe createRenderObject(BuildContext context) => _RenderOriginProbe(onMeasured);

  @override
  void updateRenderObject(BuildContext context, _RenderOriginProbe renderObject) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderOriginProbe extends RenderProxyBox {
  _RenderOriginProbe(this.onMeasured);

  _MeasuredCallback onMeasured;
  bool _scheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    _scheduleMeasure();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _scheduled = false;
      if (!attached) return;
      onMeasured(layoutOffsetToRoot(this), findTwinRoot(this));
    }, debugLabel: 'twin_screen.measure');
  }
}
