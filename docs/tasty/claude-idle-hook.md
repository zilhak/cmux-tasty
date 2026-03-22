# claude-idle Hook 이벤트

Claude Code 세션이 응답을 완료하고 idle 상태로 돌아왔을 때 fire되는 surface hook 이벤트.

## 배경

Conductor 패턴에서 worker Claude의 작업 완료를 자동으로 감지하기 위해 추가. 기존 `process-exit` 이벤트는 프로세스 종료 시에만 fire되어, Claude Code가 응답을 끝내고 `❯` 프롬프트로 돌아간 시점을 감지할 수 없었다.

## Idle 감지 원리

### Screen 상태 바 기반 감지

Claude Code TUI는 하단에 상태 바를 렌더링한다. 이 상태 바의 내용이 busy/idle 상태를 정확히 반영한다:

| 상태 | 상태 바 내용 |
|------|-------------|
| **Busy** (응답 생성 중) | `⏵⏵ bypass permissions on (shift+tab to cycle) · esc to interrupt` |
| **Idle** (프롬프트 대기) | `⏵⏵ bypass permissions on (shift+tab to cycle)` |

**핵심 차이: `esc to interrupt`의 유무.**

### 왜 ❯ 프롬프트로는 안 되는가

초기 구현에서는 `last_lines`에서 `❯` 프롬프트를 찾아 idle을 판정했으나, Claude Code TUI는 **작업 중에도 항상 `❯`를 표시**한다. 따라서 `❯` 유무만으로는 busy/idle을 구분할 수 없다.

### 왜 seconds_since_change로는 안 되는가

`claude-status` API의 `seconds_since_change`가 크다고 idle은 아니다. 빌드 같은 긴 작업에서도 출력이 없는 구간이 있어 false positive가 발생한다.

## 동작 원리

1. **3초 주기 타이머**: claude-idle hook이 등록된 surface가 있으면 타이머가 자동 시작됨
2. **screen 읽기**: 각 surface의 `read-screen --lines 3`으로 하단 상태 바를 읽음
3. **상태 판정**:
   - `esc to interrupt` 포함 → busy 마킹
   - `bypass permissions` 포함 + `esc to interrupt` 없음 → idle 후보
4. **busy→idle 전환 감지**: 이전에 busy였던 surface가 idle 후보가 되면 hook fire
5. **spawn 시 강제 busy 마킹**: `claude.spawn`에서 child를 생성할 때 즉시 busy로 마킹하여, 빠르게 완료되는 작업도 감지 가능

**핵심**: busy→idle 전환 시에만 fire. 이미 idle인 상태에서 반복 fire하지 않음.

## 사용법

```bash
# surface에 claude-idle hook 등록
cmux surface-hook set --surface surface:5 --event claude-idle --command "echo 'Claude done!'"

# claude-spawn의 --on-idle notify-parent 옵션으로 자동 설정
cmux claude-spawn --cwd /path --prompt "작업" --on-idle notify-parent
```

`--on-idle notify-parent`는 내부적으로:
- child가 idle이 되면 parent surface에 `cmux send`로 알림 메시지 주입
- `cmux notify`로 macOS 알림도 발송

## 타이머 생명 주기

- **시작**: claude-idle hook이 등록될 때 (`claude.spawn --on-idle notify-parent` 또는 `surface.set_hook`)
- **중지**: claude-idle hook이 더 이상 없을 때 (hook unset, surface close 등)
- **간격**: 3초

## 수정된 파일

- `Sources/SurfaceHookManager.swift` — Event enum에 `claudeIdle` case 추가, `surfacesWithHooks(for:)` 메서드
- `Sources/TerminalController.swift` — `claudeIdleCheckTimer`, `checkClaudeIdleSurfaces()`, `surfaceClaudeBusy` Set, spawn 시 강제 busy 마킹
