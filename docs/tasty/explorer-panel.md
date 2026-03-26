# Explorer Panel — 파일 탐색기 + 뷰어

IDE의 파일 탐색/뷰잉을 터미널 중심 환경에 가져온 패널 타입. 좌측 파일 트리 + 우측 파일 뷰어 구조.

## 배경

cmux는 터미널이 주 인터페이스이고, 파일 탐색/뷰잉은 보조적 역할이다 (IDE의 역전). Conductor 패턴에서 AI가 작업 결과물을 파일 트리로 탐색하거나, 특정 파일의 내용을 빠르게 확인하는 데 사용.

## 사용법

```bash
cmux new-split right --type explorer --path ./src/
cmux new-split down --type explorer --path .
```

## UI 구조

```
┌──────────┬──────────────────────────────┐
│ 📁 src   │  # README.md     [Raw] [Edit]│
│  📄 app  │                              │
│  📁 lib  │  This is the project...      │
│   📄 ut  │  ## Installation             │
│  📄 cfg  │  ```bash                     │
│          │  npm install                  │
│          │  ```                          │
└──────────┴──────────────────────────────┘
```

- **좌측**: 파일 트리 (디렉토리 우선 정렬, 클릭으로 확장/선택)
- **우측**: 선택한 파일의 내용
- **사이드바 너비**: 드래그로 조절 가능 (120px~400px)

## 뷰어 모드

### Markdown 파일 (.md)
- 기본: MarkdownUI로 렌더링 (heading, code block, 인용문 등)
- **[Raw]** 버튼: 원문 텍스트 보기로 전환

### 텍스트 파일 (.txt, .json, .swift, .py 등)
- 모노스페이스 폰트로 원문 표시
- 수평/수직 스크롤 지원

### Edit 모드
- **[Edit]** 버튼: 읽기 → 편집 전환
- NSTextView 기반 편집기 (undo/redo 지원)
- 미저장 변경 시 주황색 점 표시
- **⌘S** 또는 **[Save]** 버튼으로 저장
- **[Done]** 버튼으로 편집 모드 종료

## 지원 파일 타입

모든 텍스트 파일을 뷰어에서 열 수 있음:
- 마크다운: .md, .markdown
- 코드: .swift, .ts, .js, .py, .rb, .go, .rs, .java, .kt, .c, .cpp, .h
- 설정: .json, .yml, .yaml, .toml, .ini, .conf, .cfg
- 기타: .txt, .sh, .css, .html, .xml, .csv, .log, .env, .gitignore, Dockerfile, Makefile

## 파일 감시

- **디렉토리 감시**: 루트 디렉토리의 파일 생성/삭제를 DispatchSource로 실시간 감지, 트리 자동 갱신
- **파일 감시**: 선택된 파일의 수정을 감지하여 뷰어 자동 갱신 (편집 모드가 아닌 경우에만)

## 수정된 파일

- `Sources/Panels/ExplorerPanel.swift` — 파일 트리 모델, 파일 로딩, 편집/저장, 파일 감시
- `Sources/Panels/ExplorerPanelView.swift` — SwiftUI 뷰 (사이드바 + 뷰어 + 편집기)
- `Sources/Panels/Panel.swift` — `PanelType.explorer` 추가
- `Sources/Panels/PanelContentView.swift` — explorer case 라우팅
- `Sources/Workspace.swift` — `newExplorerSplit()`, SurfaceKind.explorer, session 스냅샷 분기
- `Sources/TerminalController.swift` — `surface.split` API에 explorer 타입 처리
- `Sources/ContentView.swift` — command palette에 explorer 레이블/키워드
- `CLI/cmux.swift` — `--type explorer --path <dir>` 옵션
