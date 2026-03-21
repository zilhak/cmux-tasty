# surface-hook CLI 명령

surface별 이벤트 훅을 설정/조회/해제하는 CLI 명령.

## 배경

소켓 API `surface.set_hook`, `surface.list_hooks`, `surface.unset_hook`이 이미 구현되어 있었으나, CLI에서 이 API를 직접 호출하는 명령이 없었다. AI 에이전트나 스크립트에서 surface에 이벤트 훅을 등록하고 관리할 수 있도록 CLI 명령을 추가했다.

지원 이벤트: `process-exit`, `claude-idle`

## 추가된 CLI 명령

### `cmux surface-hook set`

surface에 이벤트 훅을 등록한다. 성공 시 `hook_id`를 출력한다.

```bash
cmux surface-hook set --surface <ref> --event <event> --command <command> [--workspace <ref>]
```

**플래그:**

| 플래그 | 필수 | 설명 |
|--------|------|------|
| `--surface <id\|ref>` | yes | 대상 surface (또는 `$CMUX_SURFACE_ID`) |
| `--event <event>` | yes | 이벤트 이름: `process-exit`, `claude-idle` |
| `--command <cmd>` | yes | 훅 실행 명령어 |
| `--workspace <id\|ref>` | no | 워크스페이스 컨텍스트 (기본: `$CMUX_WORKSPACE_ID`) |

**예시:**

```bash
cmux surface-hook set --surface surface:2 --event process-exit --command "cmux notify --title done"
cmux surface-hook set --surface surface:3 --event claude-idle --command "cmux send --surface surface:1 'idle\n'"
```

**출력:**

```
hook_id: 550e8400-e29b-41d4-a716-446655440000
```

`--json` 플래그 사용 시 JSON 응답 전체를 출력한다.

---

### `cmux surface-hook list`

surface에 등록된 훅 목록을 조회한다.

```bash
cmux surface-hook list --surface <ref> [--event <event>] [--workspace <ref>]
```

**플래그:**

| 플래그 | 필수 | 설명 |
|--------|------|------|
| `--surface <id\|ref>` | yes | 대상 surface (또는 `$CMUX_SURFACE_ID`) |
| `--event <event>` | no | 이벤트로 필터링 |
| `--workspace <id\|ref>` | no | 워크스페이스 컨텍스트 |

**예시:**

```bash
cmux surface-hook list --surface surface:2
cmux surface-hook list --surface surface:2 --event process-exit
cmux surface-hook list --surface surface:2 --json
```

**출력:**

```
550e8400-e29b-41d4-a716-446655440000  process-exit  cmux notify --title done
```

훅이 없으면 `No hooks configured`를 출력한다.

---

### `cmux surface-hook unset`

훅 ID로 훅을 삭제한다.

```bash
cmux surface-hook unset --hook-id <uuid>
```

**플래그:**

| 플래그 | 필수 | 설명 |
|--------|------|------|
| `--hook-id <uuid>` | yes | 삭제할 훅의 UUID |

**예시:**

```bash
cmux surface-hook unset --hook-id 550e8400-e29b-41d4-a716-446655440000
```

## 수정된 파일

- `CLI/cmux.swift` — `surface-hook` 커맨드 구현 (set/list/unset 서브커맨드), commandHelp, usage() 목록 추가
