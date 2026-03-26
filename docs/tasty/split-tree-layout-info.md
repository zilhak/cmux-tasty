# split-tree 레이아웃 정보 및 --pane 분할 지원

AI 에이전트가 워크스페이스의 시각적 레이아웃을 정확히 이해하고, 특정 pane을 지정하여 분할할 수 있도록 개선.

## 배경

피드백 원본: `money-teller/.claude/conductor/cmux-feedback-new-split-pane.md`

Conductor 패턴에서 Claude가 `cmux new-split down --pane pane:31`으로 특정 pane을 분할하려 했으나, `--pane` 옵션이 파싱되지 않아 조용히 무시되고 항상 focused pane이 분할되는 문제가 있었다. 또한 `cmux tree` 출력에 pane 간 split 방향/비율 정보가 없어, AI가 현재 레이아웃의 시각적 구조를 이해할 수 없었다.

## 변경 내용

### 1. `system.tree` API 응답에 `split_tree` 필드 추가

workspace 노드에 bonsplit의 `treeSnapshot()` 데이터를 `split_tree`로 포함:

```json
{
  "panes": [...],
  "split_tree": {
    "type": "split",
    "orientation": "horizontal",
    "ratio": 0.5,
    "ratio_label": "50/50",
    "first": { "type": "pane", "pane_id": "...", "pane_ref": "pane:14" },
    "second": { "type": "pane", "pane_id": "...", "pane_ref": "pane:31" }
  }
}
```

재귀적 구조로, 중첩 split도 표현 가능.

### 2. CLI tree 텍스트 출력에 split 방향/비율 렌더링

기존:
```
├── pane pane:14 [focused]
└── pane pane:31
```

변경 후:
```
└── [horizontal ↔ 50/50]
    ├── pane pane:14 [focused]
    │   └── surface surface:15 [terminal] "~"
    └── pane pane:31
        └── surface surface:32 [markdown] "board.md"
```

pane이 1개만 있으면 split 헤더 없이 기존과 동일하게 표시.

### 3. `new-split`에 `--pane` 옵션 추가

**CLI**: `--pane <id|ref>` 파싱 추가. `--surface`가 지정되지 않은 경우에만 적용.

**서버**: `surface.split` API에서 `pane_id` 파라미터 처리. 해당 pane의 selected surface를 자동으로 분할 대상으로 사용.

**타겟 해석 우선순위**: `--surface` > `--pane` (selected surface) > focused surface

### 4. Help 텍스트 업데이트

`cmux help new-split` 및 전체 usage summary에 `--pane` 옵션 반영.

## 수정된 파일

- `Sources/TerminalController.swift` — `v2TreeWorkspaceNode`에 `split_tree` 추가, `v2TreeSplitTreeNode` 신규 함수, `v2SurfaceSplit`에 `pane_id` 지원
- `CLI/cmux.swift` — `new-split`에 `--pane` 파싱, `renderSplitTreeNode`/`renderPaneWithSurfaces` 신규 함수, help 업데이트
