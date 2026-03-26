# cmux hook — 글로벌 이벤트 훅

조건(타이머, 파일 변경)이 충족되면 셸 명령을 실행하는 이벤트 훅 시스템. 명령에서 cmux CLI를 사용하여 터미널/surface를 제어할 수 있다.

## 배경

Conductor 패턴에서 "5분마다 child에게 상태 보고 요청", "금지 폴더가 수정되면 Claude에게 경고" 같은 자동화가 필요하다. Claude Code의 hook은 Claude 생명주기 이벤트에 한정되지만, cmux hook은 타이머와 파일시스템 이벤트를 트리거로 사용할 수 있다.

## 조건 타입

| 조건 | 설명 | 필수 옵션 |
|------|------|----------|
| `interval` | 주기적 반복 | `--every <duration>` |
| `once` | 1회 실행 후 자동 삭제 | `--after <duration>` |
| `file-modified` | 특정 파일이 수정됨 | `--path <path>` |
| `dir-created` | 폴더에 새 파일 생성 | `--path <path>` |
| `dir-modified` | 폴더 내 파일 수정 | `--path <path>` |

Duration 형식: `30s`, `5m`, `1h`, 또는 raw 초 (`30`)

## CLI 사용법

### 생성

```bash
# 5분마다 child에게 상태 보고 요청
cmux hook create --condition interval --every 5m \
  --command 'cmux send --surface child:1 "현재 진행 상황을 알려줘\n"'

# 설정 파일 수정 감지
cmux hook create --condition file-modified --path ./config.json \
  --command 'cmux notify --title "config.json 수정됨"'

# output 폴더에 파일 생성 감지
cmux hook create --condition dir-created --path ./output/ \
  --command 'cmux send --surface parent: "새 파일: $CMUX_HOOK_FILE\n"'

# 30분 후 1회 알림
cmux hook create --condition once --after 30m \
  --command 'cmux notify --title "휴식 시간"'

# 금지 폴더 수정 감지 → Claude에게 경고
cmux hook create --condition dir-modified --path ./src/forbidden/ \
  --command 'cmux send --surface child:1 "src/forbidden/ 폴더는 수정 금지입니다. 변경사항을 되돌려주세요.\n"'

# 앱 재시작 후에도 유지 (--restart always)
cmux hook create --condition interval --every 1h --restart always \
  --command 'echo hourly check'
```

### 관리

```bash
cmux hook list              # 활성 hook 목록
cmux hook delete <hook-id>  # hook 삭제 (ID 앞 8자리만으로도 가능)
cmux hook delete-all        # 전체 삭제
cmux hook logs              # 최근 실행 로그
cmux hook logs --hook-id <id>  # 특정 hook 로그만
```

## 환경변수

hook 명령 실행 시 자동 주입:

| 변수 | 설명 |
|------|------|
| `CMUX_HOOK_ID` | hook UUID |
| `CMUX_HOOK_CONDITION` | 조건 타입 (interval, file-modified 등) |
| `CMUX_HOOK_FILE` | 변경된 파일 경로 (파일 hook만) |
| `CMUX_SURFACE_ID` | hook 생성자의 surface |
| `CMUX_WORKSPACE_ID` | hook 생성자의 workspace |

## 재시작 정책 (--restart)

Docker Compose의 `restart` 옵션과 동일한 개념:

- `no` (기본) — 앱 재시작 시 hook 소멸
- `always` — 앱 재시작 후 자동 복원. `~/Library/Application Support/cmux/hooks.json`에 저장.

## 구현

| 컴포넌트 | 방식 |
|---------|------|
| Timer hooks | `DispatchSourceTimer` — interval은 반복, once는 1회 fire 후 자동 삭제 |
| File hooks | macOS FSEvents API — 파일시스템 이벤트를 효율적으로 감시 |
| Command 실행 | `/bin/sh -c` + 환경변수 주입, 비동기 실행 |

## 수정된 파일

- `Sources/CmuxHookManager.swift` — hook 관리자, 타이머/FSEvents 감시, 명령 실행, 영속화
- `Sources/TerminalController.swift` — `hook.create/list/delete/logs` API
- `Sources/AppDelegate.swift` — 앱 시작 시 persisted hook 복원
- `CLI/cmux.swift` — `hook` CLI 서브커맨드
