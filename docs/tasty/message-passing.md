# Surface 메시지 전달 시스템

Surface 간 비동기 메시지 큐를 통한 통신 시스템. Parent-child 패턴에서 parent가 child에게 작업을 전달하거나, child가 parent에게 결과를 보고하는 데 사용.

## 배경

`cmux send`로 터미널에 텍스트를 직접 주입하는 방식은 Claude가 busy 상태일 때 입력이 무시되거나 충돌할 수 있다. 메시지 큐 방식은 수신측이 준비되었을 때 안전하게 메시지를 수신할 수 있게 한다.

## CLI 명령

### `cmux message-send`

```bash
cmux message-send --to <ref> (--content <text> | --file <path> | --stdin)
```

대상 surface의 메시지 큐에 메시지를 추가.

- `--to <ref>` — 대상 surface (child:N, surface:N 등)
- `--content <text>` — 메시지 본문
- `--file <path>` — 파일에서 읽기
- `--stdin` — stdin에서 읽기

### `cmux message-read`

```bash
cmux message-read [--wait] [--peek] [--timeout <seconds>] [--break-on-all-idle]
```

현재 surface의 메시지 큐에서 메시지를 읽음.

- `--wait` — 메시지가 도착할 때까지 blocking 대기
- `--peek` — 메시지를 읽되 큐에서 제거하지 않음
- `--timeout <seconds>` — 최대 대기 시간
- `--break-on-all-idle` — 모든 child가 idle 상태이면 메시지가 없어도 즉시 반환 (데드락 방지)

### `cmux message-count`

```bash
cmux message-count
```

현재 surface의 큐에 쌓인 메시지 수를 출력.

### `cmux message-clear`

```bash
cmux message-clear
```

현재 surface의 메시지 큐를 전부 비움.

## 소켓 API

- `message.send` — params: `to_surface_id`, `content` → 반환: `{ message_id }`
- `message.read` — params: `surface_id`, `wait`, `peek`, `timeout`, `break_on_all_idle` → 반환: `{ content }` 또는 null
- `message.count` — params: `surface_id` → 반환: `{ count }`
- `message.clear` — params: `surface_id` → 반환: OK

## `--break-on-all-idle` 데드락 방지

Parent가 `message-read --wait`으로 child의 결과를 기다리고 있는데, 모든 child가 이미 idle(작업 완료)이면 아무도 메시지를 보내지 않아 영원히 대기하는 데드락이 발생할 수 있다.

`--break-on-all-idle`를 사용하면, 대기 중에 현재 surface의 모든 child가 idle 상태인 것을 감지하면 메시지가 없어도 즉시 반환한다. 이 경우 빈 응답이 반환되므로, 호출자는 반환값으로 "메시지 수신" vs "전원 idle로 인한 중단"을 구분해야 한다.

## 사용 예시

```bash
# Parent: child에게 작업 전달
cmux message-send --to child:1 --content "src/app.ts 파일의 버그를 수정해줘"

# Child: 메시지 수신 대기
cmux message-read --wait --timeout 60

# Parent: 결과 수집 (데드락 방지)
cmux message-read --wait --break-on-all-idle

# 큐 상태 확인
cmux message-count
cmux message-clear
```

## 수정된 파일

- `Sources/TerminalController.swift` — 메시지 큐 저장소, 4개 소켓 API
- `CLI/cmux.swift` — 4개 CLI 명령
