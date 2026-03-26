# Claude Child Workspace 관리

Parent Claude가 child 전용 workspace를 생성하고 소유권을 추적하는 시스템.

## 배경

Parent-child 패턴에서 child를 동일 workspace에 split으로 배치하면 공간이 부족해질 수 있다. Child workspace를 별도로 생성하면 child마다 독립된 전체 화면 공간을 사용할 수 있으며, parent가 소유권을 추적하여 관리할 수 있다.

## CLI 명령

### `cmux claude-workspace`

```bash
cmux claude-workspace [--cwd <path>] [--title <name>] [--owner <surface>]
```

새 workspace를 생성하고 소유권 메타데이터를 설정.

- `--cwd <path>` — workspace 작업 디렉토리 (기본: 현재 디렉토리)
- `--title <name>` — workspace 제목
- `--owner <surface>` — 소유자 surface (기본: 현재 surface, $CMUX_SURFACE_ID)

출력: `OK workspace:<ref>`

### `cmux claude-workspaces`

```bash
cmux claude-workspaces [--owner <surface>]
```

지정된 owner가 소유한 child workspace 목록을 조회.

- `--owner <surface>` — 소유자 surface (기본: 현재 surface)

## 소켓 API

- `claude.child_workspace` — params: `owner_surface_id`, `cwd`, `title` → 반환: `{ workspace_id, workspace_ref }`
- `claude.child_workspaces` — params: `owner_surface_id` → 반환: `{ workspaces: [...] }`

## 사용 예시

```bash
# Child 전용 workspace 생성
cmux claude-workspace --cwd ~/project/feature-a --title "Feature A"
# OK workspace:7

# 생성한 workspace에 child spawn
cmux claude-spawn --workspace workspace:7 --prompt "feature-a 구현해줘"

# 소유한 workspace 목록 확인
cmux claude-workspaces
```

## `claude-spawn --workspace`와의 관계

`claude-spawn`에 `--workspace`를 지정하면 cross-workspace spawn이 가능하다. `claude-workspace`로 미리 workspace를 생성한 후 `claude-spawn --workspace`로 child를 배치하는 것이 일반적인 패턴.

workspace를 지정하지 않고 `claude-spawn`하면 parent와 같은 workspace에 split으로 배치된다.

## 수정된 파일

- `Sources/TerminalController.swift` — `claude.child_workspace`, `claude.child_workspaces` API
- `CLI/cmux.swift` — `claude-workspace`, `claude-workspaces` CLI 명령
