# Claude Parent-Child 관계 시스템

Claude Code surface 간의 parent-child 관계를 네이티브로 추적하고 관리하는 시스템.

## 배경

Conductor 패턴에서 orchestrator Claude가 worker Claude를 spawn할 때, 기존에는 surface 생성 → cd → claude 실행 → 프롬프트 대기 → 텍스트 전송 → Enter 제출 → hook 설정까지 7단계가 필요했다. 이를 `cmux claude-spawn` 한 줄로 통합하고, parent-child 관계를 cmux가 자동 추적하도록 했다.

## 소켓 API

### `claude.spawn`

Child Claude를 생성한다. Surface 생성, Claude 실행, 프롬프트 전송, hook 설정까지 한 번에 처리.

params:
- `parent_surface_id` (필수): parent surface UUID
- `workspace_id`: 대상 workspace (미지정 시 parent와 같은 workspace에 split)
- `cwd`: child가 작업할 디렉토리
- `prompt` / `prompt_file_path`: 초기 프롬프트
- `on_idle`: `"notify-parent"` 설정 시 child idle 전환 시 parent에 자동 메시지 주입

반환: `{ child_surface_id, child_ref, child_index, workspace_ref }`

### `claude.children`

Parent surface의 child 목록을 조회한다.

params: `surface_id` (parent)

반환: children 배열 (index, surface_id, surface_ref, cwd, idle/busy, seconds_since_change, last_lines)

### `claude.parent`

Child surface의 parent를 조회한다.

params: `surface_id` (child)

반환: `{ surface_id, surface_ref }` 또는 null

### `claude.kill_child`

Child를 종료하고 관계를 정리한다.

params: `parent_surface_id` + (`child_surface_id` 또는 `child_index`)

## CLI 명령

### `cmux claude-spawn`

```bash
cmux claude-spawn [--workspace <ref>] [--cwd <path>] [--prompt <text>] [--prompt-file <path>] [--on-idle notify-parent|none]
```

parent는 자동으로 현재 surface. 출력: `OK child:1 surface:5 workspace:2`

### `cmux claude-children`

```bash
cmux claude-children [--surface <ref>]
```

출력:
```
child:1  surface:5  3s ago   "✳ Claude Code"  → last output
child:2  surface:6  idle     "✳ Claude Code"  → TASK COMPLETE
```

### `cmux claude-parent`

```bash
cmux claude-parent [--surface <ref>]
```

### `cmux claude-kill`

```bash
cmux claude-kill <child:N | surface:N>
```

## Alias 시스템

`child:N`과 `parent:` alias가 모든 `--surface` 인자에서 사용 가능:

```bash
cmux send --surface child:1 "추가 작업"
cmux send --surface parent: "작업 완료"
cmux read-since-mark --surface child:2
```

## 수정된 파일

- `Sources/TerminalController.swift` — parent-child 데이터 구조, 4개 소켓 API, surface close 시 정리
- `CLI/cmux.swift` — 4개 CLI 명령, `parent:`/`child:N` alias 해석
