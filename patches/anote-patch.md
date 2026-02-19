# anote 对 re-editor 的补丁说明

本文档记录为 anote_app 在 re-editor 上所做的修复与行为调整，便于后续升级 re-editor 时对照迁移。

---

## 修复列表

### 1. 浮动光标松手后第一次按键不显示、第二次一起显示

**时间**：2025-02-19

**现象**：使用浮动光标移动后松手，第 1 次按键不显示，第 2 次时与第 1 次内容一起显示，之后正常；每次移动后必现。

**原因**：`updateFloatingCursor` 入口处将 `_updateCausedByFloatingCursor = true`，`updateEditingValueWithDeltas` 中若该标志为 true 会直接 return 丢弃本次输入。处理 `FloatingCursorDragState.End` 时未在分支末尾将该标志置为 false，导致松手后的第一次按键被误判丢弃。

**修改**：`lib/src/_code_input.dart`，在 `FloatingCursorDragState.End` 分支末尾增加：
- `_updateCausedByFloatingCursor = false;`
- 为该 case 补上 `break;`

---

### 2. 光标在下半屏输入时自动滚到屏幕中间

**时间**：2025-02-19

**现象**：光标在下半屏时一输入就会自动滚动到屏幕中间，体验不佳。

**原因**：多处使用 `makeCursorCenterIfInvisible()`，会将光标所在行滚动到视口正中间。

**修改**：
- `lib/src/_code_line.dart`：将所有调用处的 `makeCursorCenterIfInvisible()` 改为 `makeCursorVisible()`，仅做最小滚动使光标进入可视区域，与业内常见行为一致。
- 涉及场景：输入、选区变化、selectLine/selectLines、cancelSelection、移动选区、换行、删除等。

---

### 3. 选中行时自动滚到屏幕中间

**时间**：2025-02-19

**现象**：执行“选中行”后同样会滚动到中间。

**原因**：与修复 2 相同，`selectLines()` 等内部调用 `makeCursorCenterIfInvisible()`。

**修改**：随修复 2 一并改为 `makeCursorVisible()`，选中行后仅将选区滚入视野，不再居中。

---

### 4. 浮动光标结束时若目标不在视口内使用“居中”滚动

**时间**：2025-02-19

**现象**：浮动光标松手时若落点不在当前视口内，会使用“滚到中间”的动画。

**修改**：`lib/src/_code_input.dart`，在 End 分支中当 `finalOffset` 不可见时，将 `render.makePositionCenterIfInvisible(..., animated: true)` 改为 `render.makePositionVisible(...)`，仅将目标位置滚入可视区域。

---

### 5. 行号区滑动也会触发选中行

**时间**：2025-02-19

**现象**：在行号列滑动时会连续选中多行，期望只有“点击”行号才选中该行。

**原因**：行号在 `PointerDownEvent` 时即调用 `selectLine()`，手指滑动经过多行时每行都会触发 down，导致滑动即选中。

**修改**：`lib/src/_code_indicator.dart`，在 `CodeLineNumberRenderObject` 中：
- 增加 `_pendingTapLineIndex`、`_pointerDownGlobal` 及常量 `_kLineNumberTapSlop = 18.0`。
- **PointerDownEvent**：只记录当前行号与按下时的全局坐标，不调用 `selectLine`。
- **PointerMoveEvent**：若相对按下点位移超过 18px，视为滑动，清空待确认的 tap。
- **PointerUpEvent**：若存在待确认 tap 且抬起仍在同一行，才调用 `selectLine`。
- **PointerCancelEvent**：清空待确认 tap。

效果：仅点击（按下与抬起在同一行且位移 < 18px）会选中行，滑动不触发选中。
