# claude-wait idle 감지 수정

`claude-wait`의 idle 감지를 터미널 텍스트 파싱에서 hook 기반 플래그로 전환.

## 배경

`cmux claude-wait child:N`은 child Claude가 idle 상태가 될 때까지 blocking 대기하는 명령이다. Conductor 패턴에서 child 작업 완료를 감지하는 핵심 메커니즘으로, `run_in_background`와 함께 사용하면 Claude Code의 `<task-notification>`으로 완료 알림을 수신할 수 있다.

## 문제

기존 구현은 터미널 텍스트를 2초마다 폴링하여 마지막 줄이 `❯` (Claude Code prompt)로 시작하는지 확인하는 방식이었다.

Claude Code의 status bar (`⏵⏵ bypass permissions on (shift+tab to cycle)`)가 `❯` 프롬프트 아래에 렌더링되면서, 이 status bar 줄이 마지막 non-empty 줄이 되어 `❯` prefix 체크를 통과하지 못했다. 결과적으로 child가 실제로 idle 상태인데도 `claude-wait`가 영원히 대기하는 문제가 발생했다.

## 시행착오

처음에는 `❯` 파싱 조건을 수정하려 했다 — status bar 줄을 필터링하거나 마지막 N줄 중에서 `❯`를 찾는 방식. 그러나 사용자가 cmux의 깜빡임(flash) 기능이 이미 정확하게 idle을 감지한다는 점을 지적했다.

깜빡임은 Claude Code hook 시스템 (`claude-hook stop`)을 통해 Claude Code 자체가 "작업 끝남"을 cmux에 알리는 방식이다. 터미널 렌더링에 의존하지 않으므로 status bar 같은 변화에 영향을 받지 않는다. 따라서 동일한 hook 기반 조건을 사용하는 것이 올바른 접근이었다.

## 해결

- `TerminalController`에 `claudeHookIdleState: [UUID: Bool]` 딕셔너리 추가
- `claude-hook stop/idle` → `surface.fire_hook claude-idle` 시 해당 surface를 `idle`로 마킹
- `claude-hook active`, `prompt-submit` 시 `claude.set_idle_state` API로 `busy`로 마킹
- `v2ClaudeChildren`에서 터미널 텍스트 `❯` 파싱 대신 이 플래그를 참조하여 idle 여부 판별
- 기존 터미널 텍스트 읽기 (lastLines, secondsSinceChange)는 progress 표시용으로 유지

## 설계 결정

**왜 터미널 파싱 대신 hook인가:** 터미널 텍스트는 렌더링 변화(status bar, 테마 변경 등)에 취약하다. Hook은 Claude Code 자체가 상태를 알려주므로 100% 정확하며, 깜빡임 기능과 동일한 조건을 사용한다.

**왜 이벤트 기반이 아닌 폴링+플래그인가:** `claude-wait`는 CLI 프로세스로 실행되므로 surface hook 콜백을 직접 수신할 메커니즘이 없다. 기존 2초 폴링 인프라를 재활용하면서 판별 조건만 hook 기반 플래그로 교체했다.

## 수정된 파일

- `Sources/TerminalController.swift` — idle 상태 딕셔너리, `v2ClaudeChildren` 판별 로직, `v2SurfaceFireHook`에서 플래그 세팅
- `CLI/cmux.swift` — `claude-hook active`/`prompt-submit`에서 idle 플래그 리셋
