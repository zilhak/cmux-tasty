# cmux-tasty (fork) agent notes

> 이 저장소는 cmux 원본의 fork입니다. 원본의 CLAUDE.md 지침은 무시하세요.
> `.gitattributes`에 `CLAUDE.md merge=ours`와 `.claude/** merge=ours`가 설정되어 upstream merge 시 이 파일들이 유지됩니다.

## .claude 디렉토리 정책

`.claude/` 디렉토리는 **로컬 전용**으로 사용합니다. upstream의 `.claude/commands/` 등은 사용하지 않으며, `.gitattributes`의 `merge=ours` 설정으로 upstream merge 시 덮어쓰지 않습니다. 임시 파일, 빌드 산출물, 스크린샷 등 git에 올라가지 않는 파일들을 이 디렉토리에 저장합니다.

## 빌드 및 실행

코드 수정 후 **큰 변경이 완료되면** 반드시 Debug 빌드를 수행하여 사용자가 app 목록에서 직접 실행할 수 있도록 합니다.

**⚠️ 빌드 전에 해당 타입의 기존 빌드 산출물을 정리해야 합니다.** 여러 경로에 앱이 남아 있으면 Spotlight/Launchpad에 중복 표시되어 어떤 것이 최신인지 알 수 없습니다.

**Debug 빌드:**
```bash
find ~/Library/Developer/Xcode/DerivedData -name "cmux-tasty DEV.app" -exec rm -rf {} + 2>/dev/null
xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' build
```

**Release 빌드:**
```bash
find ~/Library/Developer/Xcode/DerivedData -name "cmux-tasty.app" -exec rm -rf {} + 2>/dev/null
rm -rf /Applications/cmux-tasty.app 2>/dev/null
rm -rf build/Build/Products/Release/cmux-tasty.app 2>/dev/null
xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Release -destination 'platform=macOS' build
```

Release는 DerivedData 외에 `/Applications/`과 프로젝트 내 `build/` 디렉토리에도 남아 있을 수 있으므로 3곳 모두 정리한다.

빌드 산출물은 Xcode 기본 DerivedData 경로에 생성됩니다. 사용자가 Spotlight 또는 앱 목록에서 "cmux DEV"를 찾아 실행하면 빌드된 버전이 실행됩니다.

컴파일만 확인하고 싶을 때 (실행 불필요):

```bash
xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/cmux-build-check build
```

## 빌드 오류 대응 정책

**빌드 오류가 발생했을 때:**

1. 자신이 수정한 코드에서 발생한 오류 → 즉시 수정
2. **자신이 수정하지 않은 코드에서 발생한 오류** → 다른 Agent가 동시에 작업 중일 수 있음. **직접 해결하지 말고 사용자에게 보고한 뒤 다음 입력을 기다릴 것.**

## 프로젝트 구조 참고

- `Sources/` — 메인 앱 소스코드 (Swift)
- `Sources/Panels/` — Panel 프로토콜 및 구현체 (TerminalPanel, BrowserPanel, MarkdownPanel, SurfaceGroup)
- `vendor/bonsplit/` — Bonsplit 라이브러리 (split pane 관리)
- `ghostty/` — Ghostty 터미널 엔진 서브모듈

## Fork 추가 CLI 명령

upstream에 없는 fork 고유 CLI 명령들:

### Mark / Delta 읽기
- `cmux set-mark` — 현재 터미널 출력 위치에 마크 설정 (이후 delta 읽기 기준점)
- `cmux read-since-mark [--surface <ref>] [--clear]` — 마크 이후 새로 추가된 출력만 읽기

### Claude 멀티에이전트
- `cmux claude-spawn [--cwd <path>] [--prompt <text>] [--prompt-file <path>]` — child Claude 프로세스 생성
- `cmux claude-respawn <child:N | surface:id> [--prompt <text>]` — child Claude 재시작
- `cmux claude-children` — child Claude 목록 조회
- `cmux claude-parent` — 부모 Claude 조회
- `cmux claude-kill <child:N | surface:N>` — child Claude 종료
- `cmux claude-wait <child:N> [--timeout <seconds>]` — child가 idle 또는 exit될 때까지 blocking 대기. `run_in_background`와 함께 사용하면 Claude Code의 `<task-notification>`으로 알림 수신 가능. idle 감지는 hook 기반 플래그 사용
- `cmux claude-status [--lines <n>]` — 워크스페이스 내 터미널 surface들의 Claude 실행 상태 확인 (마지막 변경 시간, 미리보기)
- `cmux claude-run --surface <ref> [--cwd <path>] (--prompt <text> | --prompt-file <path>)` — surface에서 Claude Code 실행 + 프롬프트 전송을 하나로 통합한 저수준 명령

### Child 워크스페이스
- `cmux claude-workspace [--cwd <path>] [--title <name>] [--owner <surface>]` — child workspace 생성 (소유권 메타데이터 포함)
- `cmux claude-workspaces [--owner <surface>]` — 현재 parent가 소유한 child workspace 목록

### Surface Hook
- `cmux surface-hook set --surface <ref> --event <event> --command <cmd>` — per-surface 이벤트 hook 관리

## Worktree 심볼릭 링크 대상

Parent Claude가 worktree를 생성할 때, 아래 디렉토리는 수정 대상이 아니므로 심볼릭 링크로 연결한다:

- `ghostty/` — 터미널 엔진 서브모듈 (~3.9GB)
- `GhosttyKit.xcframework/` — 프레임워크 바이너리 (~540MB)

## 버전 및 릴리즈

### 버전 규칙

태그 형식: `v{tasty 버전}-from-{upstream 버전}`

- tasty 버전: fork 자체의 semver (0.1.0부터 시작)
- upstream 버전: sync한 시점의 upstream `MARKETING_VERSION`
- 예시: `v0.1.0-from-0.62.2`

### 버전 올리기 기준

- **patch** (0.1.x): 같은 upstream 기반에서 fork 수정 (버그 픽스, 소규모 변경)
- **minor** (0.x.0): upstream 새로 sync 하거나 fork 자체 기능 추가
- **major** (x.0.0): 큰 구조 변경

### 릴리즈 절차

1. Release 빌드: `xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Release -destination 'platform=macOS' -derivedDataPath build build`
2. zip 패키징: `ditto -c -k --keepParent build/Build/Products/Release/cmux-tasty.app .claude/cmux-tasty.zip`
3. 태그 생성: `git tag v{tasty}-from-{upstream}`
4. GitHub Release 생성: `gh release create` 로 zip 업로드

## 설정 페이지 (Settings) 관리 정책

설정 화면은 두 곳에 존재한다:

- **Origin 설정** (`Sources/cmuxApp.swift`의 `SettingsView`) — upstream 원본 설정 화면. conflict 방지를 위해 보존만 하며, tasty 고유 기능의 설정을 여기에 추가할 필요는 없다.
- **Tasty 설정** (`Sources/TastySettingsView.swift`) — 실제 사용하는 설정 화면. 각 섹션이 별도 struct로 분리되어 있다 (General, Appearance, Sidebar, Behavior, Browser, Automation, Shortcuts 등).

**규칙:**
- **Origin에 있는 모든 설정은 Tasty에도 있어야 한다.** Upstream sync 후 Origin에 새 설정이 추가되었다면, Tasty 설정에도 동일한 `@AppStorage` 키와 UI를 추가해야 한다.
- **Tasty에만 있는 설정은 OK.** Fork 고유 기능의 설정은 Tasty에만 존재해도 된다.
- 양쪽 모두 같은 `@AppStorage` 키(UserDefaults 키)를 사용해야 설정 값이 공유된다.

## 작업 문서화

작업이 완료되면, 어떤 작업이 수행되었는지에 대해 `docs/tasty/` 하위에 문서를 작성합니다.

- 파일명은 작업 내용을 요약하는 kebab-case로 (예: `read-mark.md`, `keyboard-shortcut-fix.md`)
- 문서에는 배경, 변경 내용, 수정된 파일 목록 등을 포함
- 기존 `docs/tasty/` 문서들의 형식을 참고하여 일관성 유지
