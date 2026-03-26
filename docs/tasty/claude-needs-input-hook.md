# claude-needs-input 감지

Child Claude가 사용자 입력을 기다리는 상태(plan mode 등)에 진입했을 때 parent가 이를 감지할 수 있도록 하는 기능.

## 배경

기존에는 child Claude가 idle 상태가 되면 parent는 `claude-wait`이나 `claude-idle` surface hook으로 감지할 수 있었지만, "작업이 끝나서 idle"인지 "plan mode에 진입해서 사용자 입력을 기다리는 중"인지 구분할 수 없었다.

## 동작 원리

Claude Code의 `Notification` hook은 Claude가 사용자의 주의가 필요할 때 (plan mode 진입, permission 요청 등) fire된다. cmux는 이 hook에서:

1. 기존: 알림 발송 + "Needs input" 상태 표시
2. **추가**: `claude.set_needs_input` API로 서버에 상태 저장 + `claude-needs-input` surface hook fire

```
Claude Code: plan mode 진입 → Notification hook fire
  → cmux claude-hook notification
  → claude.set_needs_input { needs_input: true }  (서버 상태 저장)
  → surface.fire_hook claude-needs-input            (surface hook fire)
```

상태 초기화:
- `UserPromptSubmit` hook → `claude.set_idle_state { idle: false }` → 서버에서 needs_input도 자동 클리어
- `SessionStart` hook → 동일

## 사용법

### 1. Surface hook으로 즉시 감지

```bash
cmux surface-hook set --surface surface:5 --event claude-needs-input --command "echo 'Child needs input!'"
```

### 2. claude-wait로 polling 감지

`claude-wait`은 이제 3가지 상태를 구분하여 반환:

```bash
cmux claude-wait child:1
# OK child:1 idle          ← 작업 완료 후 idle
# OK child:1 needs_input   ← plan mode 등에서 입력 대기 중
# OK child:1 exited        ← 프로세스 종료
```

JSON 모드:
```bash
cmux claude-wait child:1 --json
# {"child_index": 1, "state": "needs_input"}
```

### 3. claude-children API로 직접 조회

```bash
cmux claude-children --json
# children[].status.state: "busy" | "idle" | "needs_input"
```

## 수정된 파일

- `Sources/TerminalController.swift` — `claudeHookNeedsInputState` 상태 맵 추가, `claude.set_needs_input` API, `claude.children` 응답에 `needs_input` 상태 반영, cleanup 로직
- `CLI/cmux.swift` — `notification` hook에서 needs_input 설정 + surface hook fire, `claude-wait`에서 needs_input 상태 감지, help 텍스트 업데이트
