# send --wait-idle 및 터미널 준비 대기

`cmux send`로 텍스트를 전송할 때 터미널 surface가 준비될 때까지 대기하는 기능.

## 배경

`cmux claude-spawn`으로 child를 생성한 직후 `cmux send`로 텍스트를 보내면, 터미널 surface가 아직 초기화되지 않아 Enter 키가 무시되는 문제가 있었다. 특히 Claude Code의 프롬프트가 표시되기 전에 텍스트가 도착하면 입력이 유실된다.

## 해결

`send_text` API 내부에서 대상 terminal surface의 존재를 확인하고, 아직 준비되지 않았으면 짧은 간격으로 재시도하여 surface가 바인딩될 때까지 대기한다. 외부 API 변경 없이 내부적으로 처리.

## 영향

- `cmux send` 명령의 안정성 향상
- `claude-spawn` 직후 `send`해도 입력 유실 없음
- 대기 시간은 surface 초기화에 필요한 최소 시간 (보통 수백 ms)

## 수정된 파일

- `Sources/TerminalController.swift` — `send_text` 핸들러에서 terminal surface 바인딩 대기 로직
