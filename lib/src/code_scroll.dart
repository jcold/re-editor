part of re_editor;

typedef CodeScrollbarBuilder = Widget Function(BuildContext context, Widget child, ScrollableDetails details);

class CodeScrollController {

  final ScrollController verticalScroller;
  final ScrollController horizontalScroller;

  GlobalKey? _editorKey;
  void Function(RawFloatingCursorPoint)? _floatingCursorUpdater;

  CodeScrollController({
    ScrollController? verticalScroller,
    ScrollController? horizontalScroller,
  }) : verticalScroller = verticalScroller ?? ScrollController(),
    horizontalScroller = horizontalScroller ?? ScrollController();

  void makeCenterIfInvisible(CodeLinePosition position) {
    _render?.makePositionCenterIfInvisible(position);
  }

  void makeVisible(CodeLinePosition position) {
    _render?.makePositionVisible(position);
  }

  void makeTop(CodeLinePosition position) {
    _render?.makePositionTop(position);
  }

  void bindEditor(GlobalKey key) {
    _editorKey = key;
  }

  /// 注册浮动光标更新回调，供 CodeEditor 内部使用（Touchpad 等外部输入可调用 [updateFloatingCursorFromTouchpad]）
  void registerFloatingCursorUpdater(void Function(RawFloatingCursorPoint) callback) {
    _floatingCursorUpdater = callback;
  }

  void unregisterFloatingCursorUpdater() {
    _floatingCursorUpdater = null;
  }

  /// 从 Touchpad 等外部输入驱动浮动光标（需先由 CodeEditor 注册 [registerFloatingCursorUpdater]）
  void updateFloatingCursorFromTouchpad(RawFloatingCursorPoint point) {
    _floatingCursorUpdater?.call(point);
  }

  _CodeFieldRender? get _render => _editorKey?.currentContext?.findRenderObject() as _CodeFieldRender?;

  void dispose() {
    _editorKey = null;
    _floatingCursorUpdater = null;
  }

}