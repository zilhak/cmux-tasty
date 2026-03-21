# claude-idle Hook 이벤트

Claude Code 세션이 응답을 완료하고 idle 상태(❯ 프롬프트)로 돌아왔을 때 fire되는 surface hook 이벤트.

## 배경

Conductor 패턴에서 worker Claude의 작업 완료를 자동으로 감지하기 위해 추가. 기존 `process-exit` 이벤트는 프로세스 종료 시에만 fire되어, Claude Code가 응답을 끝내고 `❯` 프롬프트로 돌아간 시점을 감지할 수 없었다.

## 동작 원리

1. `v2WorkspaceClaudeActivity()`가 호출될 때마다 (claude-status API 등) 각 surface의 출력을 검사
2. Surface의 출력이 변화하면 해당 surface를 "busy"로 마킹 (`surfaceClaudeBusy` Set에 추가)
3. 출력이 안정되고 `❯` 프롬프트가 감지되면 busy→idle 전환으로 판정
4. `SurfaceHookManager.fire(event: .claudeIdle, surfaceId:)` 호출
5. 등록된 hook 명령이 비동기로 실행됨

**핵심**: busy→idle 전환 시에만 fire. 이미 idle인 상태에서 반복 fire하지 않음.

## 사용법

```bash
# surface에 claude-idle hook 등록
cmux surface-hook set --surface surface:5 --event claude-idle --command "echo 'Claude done!'"

# claude-spawn의 --on-idle notify-parent 옵션으로 자동 설정
cmux claude-spawn --cwd /path --prompt "작업" --on-idle notify-parent
```

`--on-idle notify-parent`는 내부적으로 다음과 동일:
- child가 idle이 되면 parent surface에 `cmux send`로 알림 메시지 주입 + `cmux notify`로 macOS 알림

## 수정된 파일

- `Sources/SurfaceHookManager.swift` — Event enum에 `claudeIdle` case 추가
- `Sources/TerminalController.swift` — `surfaceClaudeBusy` Set, busy→idle 전환 감지 로직
