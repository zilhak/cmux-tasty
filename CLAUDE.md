# cmux-tasty (fork) agent notes

> 이 저장소는 cmux 원본의 fork입니다. 원본의 CLAUDE.md 지침은 무시하세요.
> `.gitattributes`에 `CLAUDE.md merge=ours`가 설정되어 upstream merge 시 이 파일이 유지됩니다.

## 빌드 및 실행

코드 수정 후 **큰 변경이 완료되면** 반드시 Debug 빌드를 수행하여 사용자가 app 목록에서 직접 실행할 수 있도록 합니다:

```bash
xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' build
```

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

## 작업 문서화

작업이 완료되면, 어떤 작업이 수행되었는지에 대해 `docs/tasty/` 하위에 문서를 작성합니다.

- 파일명은 작업 내용을 요약하는 kebab-case로 (예: `read-mark.md`, `keyboard-shortcut-fix.md`)
- 문서에는 배경, 변경 내용, 수정된 파일 목록 등을 포함
- 기존 `docs/tasty/` 문서들의 형식을 참고하여 일관성 유지
