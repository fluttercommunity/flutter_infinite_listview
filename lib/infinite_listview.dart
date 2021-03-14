library infinite_listview;

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Infinite ListView
///
/// ListView that builds its children with to an infinite extent.
///
class InfiniteListView extends StatefulWidget {
  /// See [ListView.builder]
  const InfiniteListView.builder({
    Key? key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.padding,
    this.itemExtent,
    required this.itemBuilder,
    this.itemCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.anchor = 0.0,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  })  : separatorBuilder = null,
        super(key: key);

  /// See [ListView.separated]
  const InfiniteListView.separated({
    Key? key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.padding,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.itemCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.anchor = 0.0,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  })  : itemExtent = null,
        super(key: key);

  /// See: [ScrollView.scrollDirection]
  final Axis scrollDirection;

  /// See: [ScrollView.reverse]
  final bool reverse;

  /// See: [ScrollView.controller]
  final InfiniteScrollController? controller;

  /// See: [ScrollView.physics]
  final ScrollPhysics? physics;

  /// See: [BoxScrollView.padding]
  final EdgeInsets? padding;

  /// See: [ListView.builder]
  final IndexedWidgetBuilder itemBuilder;

  /// See: [ListView.separated]
  final IndexedWidgetBuilder? separatorBuilder;

  /// See: [SliverChildBuilderDelegate.childCount]
  final int? itemCount;

  /// See: [ListView.itemExtent]
  final double? itemExtent;

  /// See: [ScrollView.cacheExtent]
  final double? cacheExtent;

  /// See: [ScrollView.anchor]
  final double anchor;

  /// See: [SliverChildBuilderDelegate.addAutomaticKeepAlives]
  final bool addAutomaticKeepAlives;

  /// See: [SliverChildBuilderDelegate.addRepaintBoundaries]
  final bool addRepaintBoundaries;

  /// See: [SliverChildBuilderDelegate.addSemanticIndexes]
  final bool addSemanticIndexes;

  /// See: [ScrollView.dragStartBehavior]
  final DragStartBehavior dragStartBehavior;

  /// See: [ScrollView.keyboardDismissBehavior]
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// See: [ScrollView.restorationId]
  final String? restorationId;

  /// See: [ScrollView.clipBehavior]
  final Clip clipBehavior;

  @override
  _InfiniteListViewState createState() => _InfiniteListViewState();
}

class _InfiniteListViewState extends State<InfiniteListView> {
  InfiniteScrollController? _controller;

  InfiniteScrollController get _effectiveController => widget.controller ?? _controller!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = InfiniteScrollController();
    }
  }

  @override
  void didUpdateWidget(InfiniteListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _controller = InfiniteScrollController();
    } else if (widget.controller != null && oldWidget.controller == null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> slivers = _buildSlivers(context, negative: false);
    final List<Widget> negativeSlivers = _buildSlivers(context, negative: true);
    final AxisDirection axisDirection = _getDirection(context);
    final scrollPhysics = widget.physics ?? const AlwaysScrollableScrollPhysics();
    return Scrollable(
      axisDirection: axisDirection,
      controller: _effectiveController,
      physics: scrollPhysics,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return Builder(builder: (BuildContext context) {
          /// Build negative [ScrollPosition] for the negative scrolling [Viewport].
          final state = Scrollable.of(context)!;
          final negativeOffset = _InfiniteScrollPosition(
            physics: scrollPhysics,
            context: state,
            initialPixels: -offset.pixels,
            keepScrollOffset: _effectiveController.keepScrollOffset,
            negativeScroll: true,
          );

          /// Keep the negative scrolling [Viewport] positioned to the [ScrollPosition].
          offset.addListener(() {
            negativeOffset._forceNegativePixels(offset.pixels);
          });

          /// Stack the two [Viewport]s on top of each other so they move in sync.
          return Stack(
            children: <Widget>[
              Viewport(
                axisDirection: flipAxisDirection(axisDirection),
                anchor: 1.0 - widget.anchor,
                offset: negativeOffset,
                slivers: negativeSlivers,
                cacheExtent: widget.cacheExtent,
              ),
              Viewport(
                axisDirection: axisDirection,
                anchor: widget.anchor,
                offset: offset,
                slivers: slivers,
                cacheExtent: widget.cacheExtent,
              ),
            ],
          );
        });
      },
    );
  }

  AxisDirection _getDirection(BuildContext context) {
    return getAxisDirectionFromAxisReverseAndDirectionality(
        context, widget.scrollDirection, widget.reverse);
  }

  List<Widget> _buildSlivers(BuildContext context, {bool negative = false}) {
    final itemExtent = widget.itemExtent;
    final padding = widget.padding ?? EdgeInsets.zero;
    return <Widget>[
      SliverPadding(
        padding: negative
            ? padding - EdgeInsets.only(bottom: padding.bottom)
            : padding - EdgeInsets.only(top: padding.top),
        sliver: (itemExtent != null)
            ? SliverFixedExtentList(
                delegate: negative ? negativeChildrenDelegate : positiveChildrenDelegate,
                itemExtent: itemExtent,
              )
            : SliverList(
                delegate: negative ? negativeChildrenDelegate : positiveChildrenDelegate,
              ),
      )
    ];
  }

  SliverChildDelegate get negativeChildrenDelegate {
    return SliverChildBuilderDelegate(
      (BuildContext context, int index) {
        final separatorBuilder = widget.separatorBuilder;
        if (separatorBuilder != null) {
          final itemIndex = (-1 - index) ~/ 2;
          return index.isOdd
              ? widget.itemBuilder(context, itemIndex)
              : separatorBuilder(context, itemIndex);
        } else {
          return widget.itemBuilder(context, -1 - index);
        }
      },
      childCount: widget.itemCount,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
    );
  }

  SliverChildDelegate get positiveChildrenDelegate {
    final separatorBuilder = widget.separatorBuilder;
    final itemCount = widget.itemCount;
    return SliverChildBuilderDelegate(
      (separatorBuilder != null)
          ? (BuildContext context, int index) {
              final itemIndex = index ~/ 2;
              return index.isEven
                  ? widget.itemBuilder(context, itemIndex)
                  : separatorBuilder(context, itemIndex);
            }
          : widget.itemBuilder,
      childCount: separatorBuilder == null
          ? itemCount
          : (itemCount != null ? math.max(0, itemCount * 2 - 1) : null),
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('scrollDirection', widget.scrollDirection));
    properties
        .add(FlagProperty('reverse', value: widget.reverse, ifTrue: 'reversed', showName: true));
    properties.add(DiagnosticsProperty<ScrollController>('controller', widget.controller,
        showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>('physics', widget.physics,
        showName: false, defaultValue: null));
    properties.add(
        DiagnosticsProperty<EdgeInsetsGeometry>('padding', widget.padding, defaultValue: null));
    properties.add(DoubleProperty('itemExtent', widget.itemExtent, defaultValue: null));
    properties.add(DoubleProperty('cacheExtent', widget.cacheExtent, defaultValue: null));
  }
}

/// Same as a [ScrollController] except it provides [ScrollPosition] objects with infinite bounds.
class InfiniteScrollController extends ScrollController {
  /// Creates a new [InfiniteScrollController]
  InfiniteScrollController({
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
  }) : super(
          initialScrollOffset: initialScrollOffset,
          keepScrollOffset: keepScrollOffset,
          debugLabel: debugLabel,
        );

  @override
  ScrollPosition createScrollPosition(
      ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    return _InfiniteScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _InfiniteScrollPosition extends ScrollPositionWithSingleContext {
  _InfiniteScrollPosition({
    required ScrollPhysics physics,
    required ScrollContext context,
    double? initialPixels = 0.0,
    bool keepScrollOffset = true,
    ScrollPosition? oldPosition,
    String? debugLabel,
    this.negativeScroll = false,
  }) : super(
          physics: physics,
          context: context,
          initialPixels: initialPixels,
          keepScrollOffset: keepScrollOffset,
          oldPosition: oldPosition,
          debugLabel: debugLabel,
        );

  final bool negativeScroll;

  void _forceNegativePixels(double value) {
    super.forcePixels(-value);
  }

  @override
  void saveScrollOffset() {
    if (!negativeScroll) {
      super.saveScrollOffset();
    }
  }

  @override
  void restoreScrollOffset() {
    if (!negativeScroll) {
      super.restoreScrollOffset();
    }
  }

  @override
  double get minScrollExtent => double.negativeInfinity;

  @override
  double get maxScrollExtent => double.infinity;
}
