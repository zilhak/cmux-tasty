# claude-idle Hook 이벤트

Claude Code 세션이 응답을 완료하고 idle 상태로 돌아왔을 때 fire되는 surface hook 이벤트.

## 배경

Conductor 패턴에서 worker Claude의 작업 완료를 자동으로 감지하기 위해 추가. 기존 `process-exit` 이벤트는 프로세스 종료 시에만 fire되어, Claude Code가 응답을 끝내고 `❯` 프롬프트로 돌아간 시점을 감지할 수 없었다.

## 동작 원리

cmux는 원래부터 Claude Code의 생명주기를 추적하고 있다. `Resources/bin/claude` wrapper가 Claude Code 실행 시 Stop hook을 자동 주입하며, 이 hook은 Claude가 응답을 완료할 때마다 `cmux claude-hook stop`을 호출한다.

**흐름:**

```
Claude Code 응답 완료
  → Claude Code의 Stop hook 실행
  → cmux claude-hook stop (기존 기능: 알림 발송 + 상태 "Idle" 표시)
  → surface.fire_hook claude-idle (추가: 등록된 hook 명령 실행)
  → SurfaceHookManager.fire(event: .claudeIdle, surfaceId:)
  → hook 명령이 비동기로 실행됨
```

별도의 타이머나 polling 없이, Claude Code 자체의 Stop hook 메커니즘을 활용한다.

## 사용법

```bash
# 수동으로 surface에 claude-idle hook 등록
cmux surface-hook set --surface surface:5 --event claude-idle --command "echo 'Claude done!'"

# claude-spawn의 --on-idle notify-parent 옵션으로 자동 설정
cmux claude-spawn --cwd /path --prompt "작업" --on-idle notify-parent
```

`--on-idle notify-parent`는 내부적으로:
1. child surface에 `claude-idle` hook을 자동 등록
2. hook 명령: `cmux send --surface {parent} --workspace {ws} "메시지"` + `cmux notify`
3. child가 idle이 되면 parent Claude Code 세션에 메시지가 자동 주입됨

## 전제 조건

- Claude Code Integration 설정이 활성화되어 있어야 함 (기본 활성)
- `CMUX_CLAUDE_HOOKS_DISABLED=1` 환경변수가 설정되어 있지 않아야 함
- Claude Code가 cmux 터미널 내부에서 실행되어야 함 (`Resources/bin/claude` wrapper 경유)

## 수정된 파일

- `Sources/SurfaceHookManager.swift` — Event enum에 `claudeIdle` case
- `Sources/TerminalController.swift` — `surface.fire_hook` API (소켓 메서드)
- `CLI/cmux.swift` — `claude-hook stop` 핸들러에서 `surface.fire_hook claude-idle` 호출
