# Keyboard Shortcut 기능 개선

설정창 Shortcuts 패널 개선 및 새 단축키 추가.

## 변경 내용

### 1. Shortcuts 서브탭 (TastySettingsView.swift)

기존: 모든 단축키가 하나의 flat list로 나열됨.
변경: ShortcutTab enum으로 카테고리별 segmented picker 제공.

카테고리:
- **General**: toggleSidebar, newTab, newWindow, closeWindow, openFolder, sendFeedback, showNotifications, jumpToUnread, triggerFlash
- **Workspace**: nextSidebarTab, prevSidebarTab, renameTab, renameWorkspace, closeWorkspace
- **Navigation**: nextSurface, prevSurface, newSurface, toggleTerminalCopyMode
- **Panes**: focusLeft/Right/Up/Down, splitRight/Down, toggleSplitZoom, splitBrowserRight/Down, nextPane, prevPane
- **Surface Group**: createSurfaceGroup, nextSurfaceInGroup, prevSurfaceInGroup
- **Panels**: openBrowser, toggleBrowserDeveloperTools, showBrowserJavaScriptConsole

### 2. Tasty/Origin 토글 우측 정렬 (cmuxApp.swift)

SettingsRootView의 TabView를 VStack+HStack+Picker 구조로 변환하여 Tasty/Origin segmented picker를 우측에 배치.

### 3. Cmd/Ctrl 숫자 단축키 swap 설정

`@AppStorage("numberShortcutModifierSwapped")` toggle 추가.
- false (기본): Cmd+1~9 = 워크스페이스, Ctrl+1~9 = Pane
- true: Cmd+1~9 = Pane, Ctrl+1~9 = 워크스페이스

수정 파일: AppDelegate.swift (keyDown 핸들러), cmuxApp.swift (메뉴 아이템), TastySettingsView.swift (설정 UI)

### 4. Pane/Surface Group 순환 단축키 (KeyboardShortcutSettings.swift)

새 Action cases:
- `nextPane` / `prevPane` (Cmd+Option+]/[): 워크스페이스 내 pane 순환
- `nextSurfaceInGroup` / `prevSurfaceInGroup` (Cmd+Option+→/←): surface group 내 surface 순환

수정 파일: KeyboardShortcutSettings.swift, AppDelegate.swift, TabManager.swift, Workspace.swift, cmuxApp.swift, TastySettingsView.swift

## 수정된 파일 목록

- `Sources/TastySettingsView.swift` — ShortcutTab enum, 서브탭 UI, swap toggle
- `Sources/cmuxApp.swift` — Tasty/Origin 우측 정렬, 메뉴 아이템 modifier 동적화, pane/surface cycling 메뉴
- `Sources/AppDelegate.swift` — keyDown 핸들러 modifier 분기, pane cycling 처리
- `Sources/KeyboardShortcutSettings.swift` — nextPane, prevPane, nextSurfaceInGroup, prevSurfaceInGroup
- `Sources/TabManager.swift` — selectNextPane, selectPrevPane
- `Sources/Workspace.swift` — pane cycling, surface group cycling 구현
