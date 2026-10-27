import 'package:flutter/material.dart';

import '../models/twin_enums.dart';
import 'fold_aware_dialog.dart';

/// Shows a modal bottom sheet that stays on one side of the fold.
///
/// Works like `showModalBottomSheet`, with the placement rules of
/// [FoldAwareDialog]: the sheet rises on the side that holds [anchorPoint] (a
/// global position), or on [preferredSide] when there is no anchor. Set
/// [allowSpanning] to let it cover both sides.
///
/// ```dart
/// showFoldAwareBottomSheet<void>(
///   context: context,
///   builder: (context) => const SizedBox(height: 240, child: Text('Share')),
/// );
/// ```
///
/// Without a fold it behaves like `showModalBottomSheet`. The scrim still
/// covers the whole screen; only the sheet is placed on one side.
Future<T?> showFoldAwareBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Offset? anchorPoint,
  TwinPaneSide preferredSide = TwinPaneSide.start,
  bool allowSpanning = false,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  AnimationStyle? sheetAnimationStyle,
}) {
  assert(debugCheckHasMediaQuery(context));
  assert(debugCheckHasMaterialLocalizations(context));
  final NavigatorState navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  return navigator.push<T>(
    FoldAwareBottomSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      anchorPoint: anchorPoint,
      preferredSide: preferredSide,
      allowSpanning: allowSpanning,
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      barrierLabel: barrierLabel ?? localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      isDismissible: isDismissible,
      modalBarrierColor: barrierColor ?? Theme.of(context).bottomSheetTheme.modalBarrierColor,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      settings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      useSafeArea: useSafeArea,
      sheetAnimationStyle: sheetAnimationStyle,
    ),
  );
}

/// A Material [ModalBottomSheetRoute] that places its sheet with
/// [FoldAwareDialog].
class FoldAwareBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  /// Creates a fold-aware bottom sheet route.
  FoldAwareBottomSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    super.showDragHandle,
    super.scrollControlDisabledMaxHeightRatio,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea,
    super.sheetAnimationStyle,
    this.preferredSide = TwinPaneSide.start,
    this.allowSpanning = false,
  });

  /// See [FoldAwareDialog.preferredSide].
  final TwinPaneSide preferredSide;

  /// See [FoldAwareDialog.allowSpanning].
  final bool allowSpanning;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FoldAwareDialog(
      anchorPoint: anchorPoint,
      preferredSide: preferredSide,
      allowSpanning: allowSpanning,
      // The route reads MediaQuery from the context it is given, so hand it one
      // that sits below FoldAwareDialog.
      child: Builder(
        builder: (BuildContext inner) => super.buildPage(inner, animation, secondaryAnimation),
      ),
    );
  }
}
