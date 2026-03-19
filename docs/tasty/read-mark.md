# Surface Read Mark (Delta Tracking)

터미널 출력의 변경분(delta)만 읽기 위한 mark/read-since-mark API.

## 배경

`read-screen`은 항상 전체 터미널 텍스트를 반환한다. AI 에이전트가 다른 터미널(예: 다른 Claude Code 인스턴스)과 상호작용할 때, 명령을 보낸 뒤 **새로 추가된 출력만** 읽고 싶은 경우가 많다. 전체 화면을 매번 파싱하는 것은 비효율적이다.

## 추가된 API

### `surface.set_read_mark` (CLI: `cmux set-mark`)

현재 터미널 출력 전체를 스냅샷으로 저장한다. 이후 `read-since-mark`가 이 시점 이후의 텍스트만 반환할 수 있도록 기준점을 만든다.

**파라미터:**

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `workspace_id` | string | no | 대상 workspace (기본: `$CMUX_WORKSPACE_ID`) |
| `surface_id` | string | no | 대상 surface (기본: focused surface) |

**CLI 사용:**

```bash
cmux set-mark
cmux set-mark --surface surface:2
```

**응답 (JSON):**

```json
{
  "ok": true,
  "result": {
    "workspace_id": "...",
    "workspace_ref": "workspace:1",
    "surface_id": "...",
    "surface_ref": "surface:2",
    "window_id": "...",
    "window_ref": "window:1"
  }
}
```

### `surface.read_since_mark` (CLI: `cmux read-since-mark`)

마지막 `set-mark` 이후 새로 추가된 터미널 텍스트만 반환한다.

- 마크가 설정되지 않은 경우: 전체 텍스트 반환 (`has_mark: false`)
- 터미널이 리셋/리플로우되어 마크 시점 텍스트가 현재 출력의 prefix가 아닌 경우: 전체 텍스트 반환

**파라미터:**

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `workspace_id` | string | no | 대상 workspace (기본: `$CMUX_WORKSPACE_ID`) |
| `surface_id` | string | no | 대상 surface (기본: focused surface) |
| `clear` | bool | no | 읽은 뒤 마크를 제거 (기본: `false`) |

**CLI 사용:**

```bash
cmux read-since-mark
cmux read-since-mark --surface surface:2
cmux read-since-mark --surface surface:2 --clear
```

**응답 (JSON):**

```json
{
  "ok": true,
  "result": {
    "text": "새로 추가된 텍스트...",
    "base64": "...",
    "has_mark": true,
    "workspace_id": "...",
    "workspace_ref": "workspace:1",
    "surface_id": "...",
    "surface_ref": "surface:2",
    "window_id": "...",
    "window_ref": "window:1"
  }
}
```

## 사용 예시

### AI 에이전트가 다른 터미널의 Claude Code를 조작하는 경우

```bash
# 1. 질문 보내기 전에 마크 찍기
cmux set-mark --surface surface:32

# 2. Claude Code에 질문 보내기
cmux send --surface surface:32 "현재 시간이 몇시야?\n"

# 3. 응답 대기 후, 새로 쓰여진 내용만 읽기
sleep 5
cmux read-since-mark --surface surface:32
```

### 연속 대화

```bash
# 첫 번째 질문
cmux set-mark --surface surface:32
cmux send --surface surface:32 "첫 번째 질문\n"
sleep 5
cmux read-since-mark --surface surface:32

# 두 번째 질문 — 마크를 다시 찍으면 기준점이 갱신됨
cmux set-mark --surface surface:32
cmux send --surface surface:32 "두 번째 질문\n"
sleep 5
cmux read-since-mark --surface surface:32
```

## 구현 세부사항

- 마크는 surface UUID를 키로 `TerminalController`의 메모리에 저장 (`surfaceReadMarks: [UUID: String]`)
- 스냅샷은 스크롤백 포함 전체 텍스트 (`includeScrollback: true`)
- delta 추출은 `String.hasPrefix` 비교 — 마크 시점 텍스트가 현재 텍스트의 prefix이면 그 뒤만 반환
- surface가 닫히면 해당 마크도 정리 필요 (향후 개선)

## 수정된 파일

- `Sources/TerminalController.swift` — `surfaceReadMarks` 프로퍼티, dispatch, capabilities, 핸들러 2개
- `CLI/cmux.swift` — CLI 명령어 2개, 도움말, usage 목록
