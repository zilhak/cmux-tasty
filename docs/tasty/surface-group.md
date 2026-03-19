# Surface Group (SurfaceGroup)

하나의 surface(탭) 안에 여러 터미널을 분할 배치하는 기능.

## 배경: 기존 구조

cmux의 UI 계층은 4단계로 구성된다:

```
Window > Workspace > Pane > Surface
```

| 단위 | 설명 | CLI 참조 |
|------|------|----------|
| **Window** | macOS 윈도우 | `window:1` |
| **Workspace** | 사이드바의 수직 탭 하나 | `workspace:1` |
| **Pane** | Bonsplit이 관리하는 분할 영역. 자체 탭 바를 가짐 | `pane:1` |
| **Surface** | Pane 안의 탭 하나 (터미널, 브라우저, 마크다운). 한 번에 하나만 보임 | `surface:1` |

기존에는 **1 Surface = 1 Panel = 1 Bonsplit Tab**으로, 각 surface가 하나의 터미널(또는 브라우저/마크다운)만 가질 수 있었다.

Pane 분할(`Cmd+D`)은 Bonsplit 레벨에서 화면 영역을 나누는 것이고, 각 Pane은 독립적인 탭 바와 surface 목록을 가진다.

## 변경된 구조: SurfaceGroup

이제 하나의 Surface가 **여러 터미널을 내부적으로 분할** 배치할 수 있다:

```
Window > Workspace > Pane > Surface
                              └─ SurfaceGroup
                                   ├── Terminal A  (horizontal split)
                                   └── Terminal B
```

SurfaceGroup은 Bonsplit의 관점에서는 여전히 **하나의 탭**이다. 탭 바에 하나의 항목으로 표시되며, Bonsplit은 내부 분할을 알지 못한다. 분할 레이아웃은 SurfaceGroup 자체의 재귀 트리(`SplitNode`)로 관리된다.

### Pane 분할 vs SurfaceGroup 분할

| | Pane 분할 (`Cmd+D`) | SurfaceGroup (`Cmd+Shift+G`) |
|---|---|---|
| 관리 주체 | Bonsplit | SurfaceGroup (앱 내부) |
| 탭 바 | 각 Pane이 독립 탭 바를 가짐 | 탭 바 하나, 탭 하나로 표시 |
| 분할 단위 | 화면 영역 | 탭 내부의 터미널 |
| 용도 | 서로 다른 작업 공간 | 관련된 터미널을 하나의 탭으로 묶기 |

## 사용법

### 단축키

| 동작 | 단축키 |
|------|--------|
| 현재 탭을 SurfaceGroup으로 변환 (또는 기존 그룹에 분할 추가) | `Cmd+Shift+G` |

### CLI

`cmux tree` 명령어로 SurfaceGroup의 내부 분할 구조를 확인할 수 있다:

```
window window:1
└── workspace workspace:1 "dev" [selected]
    └── pane pane:1 [focused]
        ├── surface surface:1 [terminal] "zsh" [selected] [group ↔]
        │   ├── surface surface:3 [terminal] "zsh" [focused]
        │   └── surface surface:4 [terminal] "zsh"
        └── surface surface:2 [terminal] "node"
```

JSON 출력(`cmux --json tree`)에서는 `surface_group` 필드로 트리 구조가 포함된다:

```json
{
  "type": "terminal",
  "surface_group": {
    "type": "split",
    "orientation": "horizontal",
    "ratio": 0.5,
    "children": [
      { "type": "surface", "id": "...", "title": "zsh", "focused": true },
      { "type": "surface", "id": "...", "title": "zsh", "focused": false }
    ]
  }
}
```

## 구현

### 주요 타입

- **`SurfaceGroup`** (`Sources/Panels/SurfaceGroup.swift`): Panel 프로토콜을 구현하는 모델. 재귀 `SplitNode` 트리로 child 터미널들을 관리. 고유 UUID를 가짐.
- **`SurfaceGroupView`** (`Sources/Panels/SurfaceGroupView.swift`): SwiftUI 뷰. SplitNode 트리를 재귀적으로 렌더링.
- **`PanelType.surfaceGroup`** (`Sources/Panels/Panel.swift`): 패널 타입 enum 값.

### panels 딕셔너리 구조

SurfaceGroup과 그 child 터미널들이 **모두** `panels`에 등록된다:

```
panels[G] = SurfaceGroup(id: G)      // 그룹 자체 (고유 UUID)
panels[X] = TerminalPanel(id: X)     // child 터미널 (원래 터미널)
panels[Y] = TerminalPanel(id: Y)     // child 터미널 (새로 생성됨)

surfaceIdToPanelId[tabId] = G        // Bonsplit 탭 → SurfaceGroup
```

이 구조 덕분에:
- `terminalPanel(for: childId)` 로 child 터미널에 직접 접근 가능
- `panels.values.compactMap { $0 as? TerminalPanel }` 로 모든 터미널 순회 시 child 포함
- `cmux send --surface` 등 CLI 명령으로 child 개별 제어 가능

### 가시성 관리

child 터미널은 Bonsplit 탭이 아니므로 `renderedVisiblePanelIdsForCurrentLayout()`에 포함되지 않는다.
대신 `surfaceGroupContaining(childId:)`로 소속 그룹을 찾아 그룹의 가시성을 따른다.

### 동작 흐름

1. `Cmd+Shift+G` → `AppDelegate`가 `workspace.splitTabIntoSurfaceGroup(tabId:)` 호출
2. SurfaceGroup이 새 UUID로 생성됨. 기존 TerminalPanel은 panels에 유지, 새 터미널도 panels에 등록
3. `surfaceIdToPanelId` 매핑이 SurfaceGroup ID로 업데이트됨
4. 이미 SurfaceGroup인 탭에서 다시 호출하면 focused child 옆에 새 분할 추가
5. 탭 닫기 시 SurfaceGroup과 모든 child의 부수 딕셔너리가 정리됨

### 수정된 파일

- `Sources/Panels/SurfaceGroup.swift` — 모델 (신규)
- `Sources/Panels/SurfaceGroupView.swift` — 뷰 (신규)
- `Sources/Panels/Panel.swift` — `PanelType.surfaceGroup` 추가
- `Sources/Panels/PanelContentView.swift` — surfaceGroup 타입 뷰 라우팅
- `Sources/KeyboardShortcutSettings.swift` — `createSurfaceGroup` 액션 + 기본 단축키
- `Sources/AppDelegate.swift` — 단축키 이벤트 핸들러
- `Sources/Workspace.swift` — `splitTabIntoSurfaceGroup()`, 포커스/닫기/가시성 등
- `Sources/ContentView.swift` — 커맨드 팔레트에 surfaceGroup 타입 추가
- `Sources/TerminalController.swift` — tree API에 surface_group 노드 출력, orphan 필터
- `CLI/cmux.swift` — tree 렌더러에서 surface_group 트리 표시
- `GhosttyTabs.xcodeproj/project.pbxproj` — 파일 등록

### 알려진 제한사항

- **세션 복원**: SurfaceGroup 스냅샷은 건너뜀. 앱 재시작 시 그룹 레이아웃은 손실되나, child 터미널 세션 자체는 개별 터미널로 복원 가능. 향후 전용 스냅샷 포맷 추가 예정.
