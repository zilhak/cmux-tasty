# Tasty Settings (Fork 전용 설정창)

upstream의 설정 항목들을 카테고리별로 재구성하고, fork 전용 기능 설정을 제공하는 설정 탭.

## 배경

upstream cmux는 단일 `SettingsView`에 모든 설정이 나열되어 있다. fork에서는 자주 쓰는 항목을 용도별로 분류하고, fork 전용 기능(워크스페이스 색상 커스터마이징, 소켓 제어 모드 등)의 설정을 추가하기 위해 별도의 설정 탭을 만들었다.

설정 윈도우에서 **Tasty** 탭(별 아이콘)이 기본 선택되고, upstream 원본 설정은 **Origin** 탭에서 접근할 수 있다.

## 구조

`NavigationSplitView` 기반의 사이드바 + 디테일 레이아웃. 사이드바에서 카테고리를 선택하면 우측에 해당 설정 섹션이 표시된다.

모든 설정은 `@AppStorage`를 통해 `UserDefaults`에 저장되며, 각 설정의 키와 기본값은 별도의 Settings 모델(`LanguageSettings`, `AppearanceSettings` 등)에 정의되어 있다.

UI 컴포넌트는 `SettingsCard`, `SettingsCardRow`, `SettingsCardDivider`, `SettingsCardNote`, `SettingsPickerRow`, `SettingsSectionHeader` 등의 공용 컴포넌트를 사용한다.

## 카테고리별 설정 항목

### General

| 설정 | 설명 |
|------|------|
| Language | 앱 언어 변경 (변경 시 재시작 안내) |
| New Workspace Placement | 새 워크스페이스 위치 (상단/하단 등) |
| Minimal Mode | 워크스페이스 타이틀바 숨기고 사이드바로 이동 |
| Keep Workspace Open When Closing Last Surface | 마지막 surface 닫을 때 워크스페이스 유지 여부 |
| Focus Pane on First Click | 비활성 상태에서 클릭 시 즉시 포커스 |
| Warn Before Quit | Cmd+Q 종료 전 확인 대화상자 |
| Show in Menu Bar | 메뉴바 아이콘 표시 |
| Rename Selects Existing Name | Command Palette 이름 변경 시 텍스트 전체 선택 |
| Command Palette Searches All Surfaces | Cmd+P에서 모든 surface 검색 |
| Send anonymous telemetry | 익명 사용 데이터 전송 |

### Appearance

**Theme 섹션:**
- Theme Picker — Light/Dark/System 모드
- App Icon Picker — 앱 아이콘 변경

**Workspace Colors 섹션:**
- Workspace Color Indicator — 사이드바 색상 표시 스타일
- 기본 팔레트 색상 커스터마이징 (ColorPicker)
- 커스텀 색상 목록 및 제거
- 팔레트 초기화 버튼

### Sidebar

**Sidebar Details 섹션:**
- Hide All Sidebar Details — 모든 상세정보 숨김 (아래 토글 비활성화)
- Sidebar Branch Layout — Vertical / Inline
- Show Notification Message
- Show Branch + Directory
- Show Pull Requests
- Open Sidebar PR Links in cmux Browser
- Show SSH
- Show Listening Ports
- Show Latest Log
- Show Progress
- Show Custom Metadata

**Sidebar Appearance 섹션:**
- Light Mode Tint — 라이트 모드 사이드바 틴트 색상
- Dark Mode Tint — 다크 모드 사이드바 틴트 색상
- Tint Opacity — 틴트 투명도 슬라이더

### Notifications

- Desktop Notifications — 시스템 알림 권한 상태 표시 및 활성화/설정
- Send Test — 테스트 알림 발송
- Reorder on Notification — 알림 시 워크스페이스를 상단으로 이동
- Dock Badge — 앱 아이콘에 읽지 않은 개수 표시
- Unread Pane Ring — 읽지 않은 pane 링 효과
- Pane Flash — pane 깜빡임 효과
- Notification Sound — 시스템 사운드 목록에서 선택
- Notification Command — 알림 시 실행할 커스텀 명령어

### Browser

- Default Search Engine — 검색 엔진 선택
- Show Search Suggestions — 검색 제안 표시
- Browser Theme — 브라우저 테마 모드
- Open Terminal Links in cmux Browser — 터미널 링크를 내장 브라우저에서 열기
- Intercept open http(s) in Terminal — `open` 명령 가로채기
- Hosts to Open in Embedded Browser — 내장 브라우저로 열 호스트 화이트리스트 (TextEditor)
- URLs to Always Open Externally — 항상 외부 브라우저로 열 URL 패턴 (TextEditor)
- Browsing History — 히스토리 삭제 (확인 대화상자 포함)

### Automation

**Socket Control 섹션:**
- Socket Control Mode — Picker (off / password / allowAll)
- Socket Password — 비밀번호 설정/변경/삭제 (password 모드일 때만 표시)
- Full Open Access 경고 (allowAll 모드일 때만 표시, 확인 대화상자 포함)

**Claude Code Integration 섹션:**
- Claude Code Integration — 사이드바에 Claude 세션 상태/알림 표시

**Port 섹션:**
- Port Base — 워크스페이스별 포트 시작 번호
- Port Range Size — 포트 범위 크기

### Shortcuts

**전역 설정:**
- Show Cmd/Ctrl-Hold Shortcut Hints — Cmd/Ctrl 홀드 시 단축키 힌트 표시
- Swap Cmd/Ctrl Number Shortcuts — Cmd+1~9(워크스페이스)와 Ctrl+1~9(Pane) modifier 교환 토글

**서브탭:** Segmented Picker로 카테고리별 단축키 표시.
- General / Workspace / Navigation / Panes / Surface Group / Panels
- 각 탭에서 해당 카테고리의 키보드 단축키를 표시/녹화

상세: [keyboard-shortcut-enhancements.md](keyboard-shortcut-enhancements.md)

## 헬퍼

`TastySettingsHelper.relaunchApp()` — 언어 변경 등 재시작이 필요할 때 앱을 재실행하는 유틸리티. `/bin/sh`로 1초 후 `open -n`을 실행한 뒤 현재 앱을 종료한다.

## 수정된 파일

- `Sources/TastySettingsView.swift` — 설정 뷰 전체 (7개 카테고리 섹션 + 헬퍼)
- `Sources/cmuxApp.swift` — 설정 윈도우에 Tasty 탭 추가, 기본 선택 탭을 `.tasty`로 설정
