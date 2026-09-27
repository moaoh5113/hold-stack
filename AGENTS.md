# AGENTS.md

macOS 메뉴 막대 앱. 질문을 스택에 보관하고 전역 단축키로 꺼낸다. SwiftPM 단일 패키지, 외부 의존성 없음.

## 명령

| 목적 | 명령 |
|---|---|
| 로직 검증 | `swift run HoldCoreCheck` (종료 코드 0 = 통과) |
| 앱 빌드 | `swift build --product HoldStack` |
| .app 번들 | `./scripts/make-app.sh` → `build/HoldStack.app` |
| 아이콘 다시 만들기 | `./scripts/make-icon.sh` → `Resources/AppIcon.icns`, `AppIcon.png` |
| 실행 | `open build/HoldStack.app` |

## 구조

| 경로 | 역할 |
|---|---|
| `Sources/HoldCore/HoldStore.swift` | 스택. `items[0]` 이 맨 위. 항목은 질문 `text` + 문장 `quote`. `pasteText` 가 붙여넣기 형식. JSON 영속화, 1단계 undo |
| `Sources/HoldCore/PanelAppearance.swift` | 패널 투명도(0.3~1.0), UserDefaults |
| `Sources/HoldCore/Shortcut.swift` | 단축키 값, `HotKeyAction`, `ShortcutSettings`(UserDefaults, 검증) |
| `Sources/HoldCoreCheck/main.swift` | 테스트 대용 실행 파일 |
| `Sources/HoldStack/AppDelegate.swift` | 메뉴 막대, 단축키 등록·재등록, 설정 창 |
| `Sources/HoldStack/HotKeyCenter.swift` | Carbon `RegisterEventHotKey` 래퍼 |
| `Sources/HoldStack/Clipboard.swift` | 합성 ⌘C/⌘V, 클립보드 복원 |
| `Sources/HoldStack/PanelController.swift` | 떠 있는 패널, 작성 모드(`composing`)와 목록 모드 키 처리, 위치와 크기 자동 저장 |
| `Sources/HoldStack/HoldView.swift` | 패널 SwiftUI 뷰 |
| `Sources/HoldStack/SettingsView.swift` | 설정 창, 단축키 녹화, 투명도 |
| `scripts/make-icon.swift` | 아이콘을 코드로 그린다 |

## 지켜야 할 것

| 규칙 | 이유 |
|---|---|
| XCTest, `import Testing` 쓰지 않는다 | CLT 에 XCTest 가 없고 Testing 매크로 플러그인도 없다. 새 검사는 `HoldCoreCheck` 에 `check(...)` 로 추가 |
| SwiftUI `@State` 쓰지 않는다 | 이 SDK 에서 매크로라 CLT 빌드가 깨진다. 상태는 `ObservableObject` + `@ObservedObject`. `@FocusState`, `@Published` 는 된다 |
| 패널은 `.nonactivatingPanel` 유지 | 원래 앱이 앞에 남아 있어야 합성 ⌘V 가 그 앱으로 간다 |
| 패널 키 처리에서 `hasMarkedText()` 먼저 본다 | 한글 조합 중 Enter 를 가로채면 마지막 글자가 사라진다 |
| 단축키 녹화 중에는 `HotKeyCenter.unregisterAll()` | 전역 단축키가 먼저 키를 먹어서 설정 창에 안 온다 |
| 녹화를 끝내는 경로는 키 입력, 앱 비활성화, 창 닫기 셋 다 | 하나라도 빠지면 전역 단축키가 꺼진 채 남는다 |
| 클립보드는 `snapshot()` 으로 모든 형식을 저장한다 | 문자열만 저장하면 복사해 둔 이미지와 파일이 사라진다 |
| 스택에서 빼기 전에 `Clipboard.isBusy` 를 본다 | 복원 전 두 번째 붙여넣기가 앞 항목을 "원래 클립보드"로 저장한다 |
| `HoldItem` 에 필드를 더할 때는 옵셔널로 | 옛 `stack.json` 에 없는 키라서, 필수 필드면 저장된 스택 전체를 못 읽는다 |
| 패널 `TextField` 는 한 줄로 둔다 | `axis: .vertical` 은 한글 조합 중 Enter 처리가 달라진다 |
| 패널 위치는 `setFrameAutosaveName("HoldStackPanel")` 이 저장한다 | 직접 저장 코드를 따로 두지 않는다 |
| `main.swift` 의 숨은 Edit 메뉴를 지우지 않는다 | `.accessory` 앱은 이게 없으면 입력칸에서 ⌘C ⌘V ⌘A 가 안 먹는다 |
| 패널이 떠 있을 때 hold 단축키는 포커스만 준다 | 다시 열면 쓰던 질문과 문장이 지워진다 |
| 개인 정보를 넣지 않는다 | 배포용이다. 번들 ID 는 `app.holdstack.HoldStack`. 사람 이름, 계정, 절대 경로를 코드와 문서에 쓰지 않는다 |
| 순수 로직은 `HoldCore` 에 둔다 | 자동 검증이 되는 곳은 거기뿐이다 |
| `switch` 에서 `case A, B where cond` 금지 | `where` 가 B 에만 걸린다. `case A where cond, B where cond` |

## 자동 검증이 안 되는 것

전역 단축키, 패널 조작, 다른 앱에 붙여넣기는 사람이 확인한다. 합성 키 입력에 터미널의 손쉬운 사용 권한이 필요하기 때문이다.
변경 후 README 「사용법」 표의 키를 한 번씩 눌러본다. 설정 변경 후에는 새 조합이 곧바로 먹는지, 옛 조합이 풀렸는지 본다. 클립보드를 건드렸으면 이미지를 복사해 둔 채 ⌃⇧P 를 누르고 이미지가 남는지 본다.

ad-hoc 서명이라 재빌드마다 손쉬운 사용 권한이 풀린다. 붙여넣기가 안 되면 먼저 권한을 다시 켠다.
