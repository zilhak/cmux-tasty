# Claude Parent-Child 관계 시스템

Claude Code surface 간의 parent-child 관계를 네이티브로 추적하고 관리하는 시스템.

## 배경

Parent-child 패턴에서 parent Claude가 child Claude를 spawn할 때, 기존에는 surface 생성 → cd → claude 실행 → 프롬프트 대기 → 텍스트 전송 → Enter 제출 → hook 설정까지 7단계가 필요했다. 이를 `cmux claude-spawn` 한 줄로 통합하고, parent-child 관계를 cmux가 자동 추적하도록 했다.

## 소켓 API

### `claude.spawn`

Child Claude를 생성한다. Surface 생성, Claude 실행, 프롬프트 전송, hook 설정까지 한 번에 처리.

params:
- `parent_surface_id` (필수): parent surface UUID
- `workspace_id`: 대상 workspace (미지정 시 parent와 같은 workspace에 split). Cross-workspace spawn 가능.
- `cwd`: child가 작업할 디렉토리
- `prompt` / `prompt_file_path`: 초기 프롬프트
- `on_idle`: `"notify-parent"` 설정 시 child idle 전환 시 parent에 자동 메시지 주입
- `role`: child의 역할 식별자 (예: "reviewer", "tester")
- `nickname`: child의 표시 이름

반환: `{ child_surface_id, child_ref, child_index, workspace_ref }`

**Grid-aware 레이아웃**: spawn 시 기존 pane들의 공간 좌표를 분석하여 최적의 split 방향을 자동 결정. 가로로 넓은 pane은 세로 분할, 세로로 긴 pane은 가로 분할. 분할 후 균등 비율 재조정(proportional equalize)도 자동 수행.

### `claude.children`

Parent surface의 child 목록을 조회한다.

params: `surface_id` (parent)

반환: children 배열 (index, surface_id, surface_ref, cwd, role, nickname, status: {state: idle/busy/needs_input, seconds_since_change, last_lines})

### `claude.parent`

Child surface의 parent를 조회한다.

params: `surface_id` (child)

반환: `{ surface_id, surface_ref }` 또는 null

### `claude.kill_child`

Child를 종료하고 관계를 정리한다.

params: `parent_surface_id` + (`child_surface_id` 또는 `child_index`)

### `claude.respawn`

종료되거나 충돌한 child Claude를 재시작한다. 기존 surface에서 새 Claude 프로세스를 시작.

params:
- `parent_surface_id` (필수): parent surface UUID
- `child_surface_id` 또는 `child_index`: 재시작할 child
- `prompt` / `prompt_file_path`: 새 프롬프트 (미지정 시 원래 프롬프트 재사용)

### `claude.broadcast`

모든 child에게 메시지를 동시에 전송한다.

params:
- `surface_id` (parent)
- `text`: 전송할 텍스트
- `role`: 특정 역할의 child만 대상 (선택사항)

## CLI 명령

### `cmux claude-spawn`

```bash
cmux claude-spawn [--workspace <ref>] [--cwd <path>] [--prompt <text>] [--prompt-file <path>] [--on-idle notify-parent|none] [--role <role>] [--nickname <name>]
```

parent는 자동으로 현재 surface. 출력: `OK child:1 surface:5 workspace:2`

Cross-workspace spawn: `--workspace`에 다른 workspace를 지정하면 해당 workspace에 child를 생성. parent workspace와 분리된 레이아웃에서 작업 가능.

### `cmux claude-children`

```bash
cmux claude-children [--surface <ref>]
```

출력:
```
child:1  surface:5  3s ago   "✳ Claude Code"  → last output
child:2  surface:6  idle     "✳ Claude Code"  → TASK COMPLETE
```

`--json` 사용 시 role, nickname, status.state (busy/idle/needs_input) 등 상세 정보 포함.

### `cmux claude-parent`

```bash
cmux claude-parent [--surface <ref>]
```

### `cmux claude-kill`

```bash
cmux claude-kill <child:N | surface:N>
```

### `cmux claude-respawn`

```bash
cmux claude-respawn <child:N | surface:id> [--prompt <text>] [--prompt-file <path>]
```

종료/충돌된 child를 동일한 surface에서 재시작. 새 프롬프트를 지정하지 않으면 원래 프롬프트를 재사용.

### `cmux claude-broadcast`

```bash
cmux claude-broadcast (--prompt <text> | --prompt-file <path> | --stdin) [--role <role>]
```

모든 child Claude에게 텍스트를 동시 전송. `--role` 지정 시 해당 역할의 child만 대상.

## Role / Nickname 메타데이터

child 생성 시 role과 nickname을 부여하여 식별 가능:

```bash
cmux claude-spawn --role reviewer --nickname "리뷰어" --prompt "코드 리뷰해줘"
cmux claude-spawn --role tester --nickname "테스터" --prompt "테스트 작성해줘"

# 특정 역할의 child만 대상으로 브로드캐스트
cmux claude-broadcast --role reviewer --prompt "리뷰 결과 알려줘"
```

`cmux claude-children --json`에서 각 child의 `role`과 `nickname` 필드 확인 가능.

## Ghost Cleanup

### Ghost child (surface 닫힘)
UI에서 child surface를 직접 닫으면 parent의 child registry에서 자동 제거. `onPanelClosed` 콜백으로 감지.

### Ghost parent (parent surface 닫힘)
Parent surface가 닫혀도 child registry는 보존. child는 계속 동작하며, parent가 없는 child도 `claude-parent`로 조회 시 null 반환.

## Orphaned Claude Process Cleanup

앱 종료 시 실행 중인 Claude 프로세스가 고아가 되지 않도록 SIGKILL로 정리. SIGTERM은 Claude Code가 무시하므로 SIGKILL 사용.

## Alias 시스템

`child:N`과 `parent:` alias가 모든 `--surface` 인자에서 사용 가능:

```bash
cmux send --surface child:1 "추가 작업"
cmux send --surface parent: "작업 완료"
cmux read-since-mark --surface child:2
```

## 수정된 파일

- `Sources/TerminalController.swift` — parent-child 데이터 구조, 소켓 API, surface close 시 정리, orphaned cleanup
- `CLI/cmux.swift` — CLI 명령, `parent:`/`child:N` alias 해석
