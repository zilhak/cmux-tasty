# Socket Listener 좀비 상태 방지

소켓 리스너의 resume/rearm 경로 실패 시 좀비 상태가 되는 문제를 수정.

## 배경

`TerminalController`의 소켓 accept 루프에서 `accept()` 실패 시 `scheduleAcceptLoopResume` 또는 `scheduleListenerRearm`이 스케줄된다. 그런데 스케줄된 콜백이 실행될 때 아래 조건에서 조용히 early return하면서, 소켓은 열려 있고 `isRunning=true`이지만 아무도 `accept()`를 호출하지 않는 좀비 상태가 발생했다:

- `weak self`가 nil로 해제된 경우
- generation 불일치로 early return하는 경우
- `tabManager`가 nil인 경우 (rearm 경로)

외부에서 connect하면 Connection refused가 발생하는 심각한 문제.

## 변경 내용

### `scheduleAcceptLoopResume` (약 1499행)

- `weak self`가 nil일 때 진단 로그 출력
- generation/상태 검증에서 단순 `false` 대신 `ResumeDecision` enum을 사용하여 좀비 상태 감지
- 좀비 감지 시 (`socket_mismatch`, `not_running`) `self.stop()` 호출로 소켓 정리
- Sentry breadcrumb으로 좀비 정리 이벤트 기록

### `scheduleListenerRearm` (약 1582행)

- `weak self`가 nil일 때 진단 로그 출력
- `tabManager`가 nil일 때 `self.stop()` 호출로 소켓 정리 (기존: 조용히 return)
- generation 불일치 시 좀비 상태 추가 점검 (`isRunning && !acceptLoopAlive && activeAcceptLoopGeneration == 0`), 해당 시 `self.stop()` 호출

## 수정된 파일

- `Sources/TerminalController.swift`
