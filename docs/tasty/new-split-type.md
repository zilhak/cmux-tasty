# new-split --type 옵션

`cmux new-split`에서 terminal 외에 browser, markdown 타입의 패널을 직접 생성할 수 있는 기능.

## 배경

기존 `new-split`은 항상 terminal surface만 생성했다. Conductor 패턴에서 마크다운 문서나 브라우저를 split으로 배치하려면 별도의 API를 조합해야 했다.

## 사용법

```bash
cmux new-split <left|right|up|down> [--type <terminal|browser|markdown>] [--url <url>] [--file <path>]
```

- `--type terminal` (기본) — 터미널 surface 생성
- `--type browser` — 브라우저 surface 생성. `--url`로 초기 URL 지정 가능.
- `--type markdown` — 마크다운 뷰어 surface 생성. `--file` 필수.

## 예시

```bash
# 오른쪽에 브라우저 열기
cmux new-split right --type browser --url https://example.com

# 아래에 마크다운 뷰어 열기
cmux new-split down --type markdown --file ./README.md

# 특정 pane을 분할하여 마크다운 추가 (--pane 옵션과 조합)
cmux new-split down --pane pane:3 --type markdown --file ./notes.md
```

## 수정된 파일

- `Sources/TerminalController.swift` — `v2SurfaceSplit`에서 panelType별 분기 처리
- `Sources/Workspace.swift` — `newBrowserSplit`, `newMarkdownSplit` 메서드
- `CLI/cmux.swift` — `--type`, `--url`, `--file` 옵션 파싱
