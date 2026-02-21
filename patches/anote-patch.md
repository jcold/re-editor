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

---

### 6. iOS 跨行选区（起点在行尾）退格多删一字

**时间**：2025-02-21

**现象**：仅 **iOS** 出现。光标在上一行行尾（该行未选任何字符），把选区拉到下一行后按退格删除时，除正确删除跨行选区外，会**多删掉上一行最后一个字符**。第一行若有选中字符则正常；Android 无此问题。

**原因**：
1. 跨行且起点在行尾时，`_buildTextEditingValue()` 只向 IME 发送当前基行文本，选区被设为 `(line.length, line.length)`，即**折叠选区**，IME 认为“无选区、光标在行尾”。
2. 退格被处理两次：我们先在 `onKey` 里执行 `deleteBackward()` → `_deleteSelection()` 正确合并；iOS 上 IME 仍会再发“删前一字符”的 delta，再执行一次 `edit(newValue)`，在已合并内容上多删一字。
3. Android 上返回 `KeyEventResult.handled` 后 IME 通常不再发 delta，故不表现；iOS 仍会发，导致双重处理。

**修改**：
- **`lib/src/code_editor.dart`**：iOS 上退格键不再在 `onKey` 里处理，改为返回 `KeyEventResult.ignored`，退格只通过 IME 的 delta 驱动，避免与 key 双重处理。
- **`lib/src/_code_input.dart`**：在 `updateEditingValueWithDeltas` 中，当当前为跨行选区且起点在行尾、且本次 delta 结果为“基行少最后一字、选区折叠在行末前一位”时，不按单行少一字走 `edit()`，而是解释为删除整段选区，调用 `deleteSelection()`，并同步 `_remoteEditingValue`。
