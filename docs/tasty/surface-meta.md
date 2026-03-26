# Surface 메타데이터 저장소

Surface별 key-value 메타데이터를 저장하고 조회하는 시스템. AI 에이전트가 surface에 임의의 상태 정보를 태깅할 수 있다.

## 배경

Conductor 패턴에서 parent가 child surface에 역할, 작업 ID, 상태 등의 메타데이터를 부여하고 나중에 조회해야 하는 경우가 있다. parent-child 관계의 role/nickname과 별개로, surface 자체에 자유 형식의 key-value 데이터를 저장할 수 있는 범용 저장소.

## CLI 명령

### `cmux surface-meta set`

```bash
cmux surface-meta set --surface <ref> --key <key> --value <value>
```

surface에 key-value 쌍을 저장. 같은 key가 이미 있으면 덮어씀.

### `cmux surface-meta get`

```bash
cmux surface-meta get --surface <ref> --key <key>
```

특정 key의 값을 출력. 존재하지 않으면 에러.

### `cmux surface-meta unset`

```bash
cmux surface-meta unset --surface <ref> --key <key>
```

특정 key를 제거.

### `cmux surface-meta list`

```bash
cmux surface-meta list [--surface <ref>]
```

surface의 모든 메타데이터를 JSON으로 출력.

## 소켓 API

- `surface.meta_set` — params: `surface_id`, `key`, `value`
- `surface.meta_get` — params: `surface_id`, `key` → 반환: `{ value }`
- `surface.meta_unset` — params: `surface_id`, `key`
- `surface.meta_list` — params: `surface_id` → 반환: `{ metadata: { key: value, ... } }`

## 사용 예시

```bash
# child에 작업 메타데이터 태깅
cmux surface-meta set --surface child:1 --key task-id --value "PROJ-123"
cmux surface-meta set --surface child:1 --key status --value "in-progress"

# 나중에 조회
cmux surface-meta get --surface child:1 --key task-id
# 출력: PROJ-123

# 전체 메타데이터 확인
cmux surface-meta list --surface child:1
# 출력: {"task-id":"PROJ-123","status":"in-progress"}

# 정리
cmux surface-meta unset --surface child:1 --key status
```

## 저장 구조

서버 메모리 내 `SurfaceMetaStore`에 per-surface dictionary로 저장. surface가 닫히면 해당 메타데이터도 정리됨.

## 수정된 파일

- `Sources/SurfaceMetaStore.swift` — 메타데이터 저장소 클래스
- `Sources/TerminalController.swift` — 4개 소켓 API
- `CLI/cmux.swift` — `surface-meta` CLI 서브커맨드
