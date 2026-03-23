# claude-run CLI 명령

Claude Code 실행과 프롬프트 전송을 하나의 명령으로 통합한 CLI 명령.

## 배경

cmux surface에서 Claude Code를 실행하고 프롬프트를 보내려면 cd → claude 실행 → ❯ 대기 → 텍스트 전송 → Enter 제출까지 여러 단계가 필요했다. `claude-run`은 이를 하나로 통합한다.

참고: `claude-spawn`이 parent-child 관계 추적까지 포함하는 상위 기능이므로, parent-child 패턴에서는 `claude-spawn`을 사용하는 것이 권장된다. `claude-run`은 단순히 "이 surface에서 claude를 띄우고 프롬프트를 보내는" 저수준 명령이다.

## 사용법

```bash
cmux claude-run --surface <ref> [--workspace <ref>] [--cwd <path>] (--prompt <text> | --prompt-file <path>) [--timeout <seconds>]
```

| 플래그 | 필수 | 설명 |
|--------|------|------|
| `--surface` | yes | 대상 surface (또는 `$CMUX_SURFACE_ID`) |
| `--workspace` | no | 워크스페이스 (기본 `$CMUX_WORKSPACE_ID`) |
| `--cwd` | no | claude 실행 전 cd할 경로 |
| `--prompt` | * | 프롬프트 텍스트 (prompt-file과 택 1) |
| `--prompt-file` | * | 프롬프트 파일 경로 |
| `--timeout` | no | ❯ 프롬프트 대기 최대 시간 (기본 30초) |

## 동작 순서

1. `--cwd` 지정 시 `cd` 명령 전송
2. `claude --dangerously-skip-permissions` 전송
3. ❯ 프롬프트 폴링 (0.5초 간격, 최대 timeout)
4. 프롬프트 텍스트 전송
5. 0.5초 대기 후 Enter 전송
6. `OK` 출력

## 수정된 파일

- `CLI/cmux.swift` — `claude-run` case 추가 (약 98줄)
