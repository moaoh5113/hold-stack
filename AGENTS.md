# AGENTS.md

macOS 메뉴 막대 앱. 질문을 스택에 보관하고 전역 단축키로 꺼낸다. SwiftPM 단일 패키지, 외부 의존성 없음.

## 명령

| 목적 | 명령 |
|---|---|
| 로직 검증 | `swift run HoldCoreCheck` (종료 코드 0 = 통과) |
| 앱 빌드 | `swift build --product HoldStack` |
| .app 번들 | `./scripts/make-app.sh` → `build/HoldStack.app`. 인증서가 있으면 그걸로 서명 |
| 배포용 번들 | `./scripts/make-app.sh --release` (임시 서명만) |
| 배포 zip | `./scripts/make-release.sh` → `build/release/HoldStack-<버전>.zip` (앱과 LICENSE, 인텔 겸용). 올리기 `gh release upload v<버전> <zip> --clobber` |
| 이 컴퓨터 전용 인증서 | `./scripts/make-cert.sh` (한 번만). 지우기 `security delete-identity -c "HoldStack Local Signing"` |
| 번역 빠짐 확인 | `./scripts/check-l10n.sh` (코드의 `L("…")` 가운데 영어 표에 없는 것) |
| 아이콘 다시 만들기 | `./scripts/make-icon.sh` → `Resources/AppIcon.icns`, `AppIcon.png` |
| 실행 | `open build/HoldStack.app` |

## 구조

| 경로 | 역할 |
|---|---|
| `Sources/HoldCore/HoldStore.swift` | 스택과 휴지통. `items[0]`, `trash[0]` 이 최근. 항목은 질문 `text` + 문장 `quote`. `pasteText` 가 붙여넣기 형식. `stack.json`, `trash.json`, undo 최대 10단계(`undo.json`) |
| `Sources/HoldCore/Preferences.swift` | 투명도, 불러온 뒤 닫기, 개수 표시, 초점 잃으면 닫기(이유별), 펼치기 방식, 글자 크기(10~24pt). UserDefaults |
| `Sources/HoldCore/Shortcut.swift` | 단축키 값, `HotKeyAction`, `ShortcutSettings`(UserDefaults, 검증) |
| `Sources/HoldCoreCheck/main.swift` | 테스트 대용 실행 파일 |
| `Sources/HoldStack/AppDelegate.swift` | 메뉴 막대, 단축키 등록·재등록, 설정 창 |
| `Sources/HoldStack/HotKeyCenter.swift` | Carbon `RegisterEventHotKey` 래퍼 |
| `Sources/HoldStack/Clipboard.swift` | 합성 ⌘C/⌘V, 클립보드 복원 |
| `Sources/HoldStack/InputSource.swift` | 키를 보내는 동안만 영문 자판으로 바꾸고 되돌린다 |
| `Sources/HoldStack/PanelController.swift` | 목록 창. 스택/휴지통 모드 키 처리, 붙여넣을 앱 추적, 위치와 크기 자동 저장 |
| `Sources/HoldStack/ComposeController.swift` | ⌃⇧H 작성 창과 그 뷰. 목록 창과 별개 |
| `Sources/HoldStack/LoginItem.swift` | 로그인 시 자동 실행 (`SMAppService`) |
| `Sources/HoldStack/FocusLossWatcher.swift` | 다른 앱 클릭, ⌘⇥, 데스크탑 전환을 이유(`FocusLossReason`)와 함께 알린다. 내릴지는 `Preferences.shouldHide` |
| `Sources/HoldCore/Age.swift` | 목록의 경과 시간 문구 (분 단위) |
| `Sources/HoldCore/ListNav.swift` | 목록 이동 계산. 양끝 순환(`wrapped`), 화면 번호를 배열 자리로(`index(forNumber:)`), 숫자 키 버퍼(`NumberJump`) |
| `Sources/HoldCore/FocusInfo.swift` | 초점 요소가 입력칸인지 가리는 규칙. 실제 앱에서 읽은 값으로 검사한다 |
| `Sources/HoldStack/FocusProbe.swift` | 붙여넣을 앱의 초점 요소 종류를 AX 로 읽는다 |
| `Sources/HoldCore/ScreenFit.swift` | 창을 화면 안 어디에 놓을지 계산. 가운데 놓기, 다른 화면으로 비율 옮기기 |
| `Sources/HoldStack/ActiveScreen.swift` | 초점이 가 있는 화면 고르기(AX 초점 창 → 마우스 → `NSScreen.main`)와 창 옮기기 |
| `Sources/HoldStack/DiagLog.swift` | `~/Library/Logs/HoldStack.log`. 권한과 붙여넣기 대상만 적는다 |
| `Sources/HoldStack/HoldView.swift` | 목록 창 SwiftUI 뷰 |
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
| 합성 ⌘C/⌘V 는 `InputSource.useASCII()` 로 감싸고, 실제로 영문이 된 뒤에 보낸다 | 조합 입력기가 켜져 있으면 받는 쪽에 `c`, `v` 가 아니라 `ㅊ`, `ㅍ` 로 번역되어 닿는다. kitty 키보드 프로토콜을 쓰는 터미널(herdr 등)에서 복사가 통째로 실패한다. 자판 전환은 즉시가 아니라서 기다려야 한다 |
| 클립보드는 `snapshot()` 으로 모든 형식을 저장한다 | 문자열만 저장하면 복사해 둔 이미지와 파일이 사라진다 |
| 스택에서 빼기 전에 `Clipboard.isBusy` 를 본다 | 복원 전 두 번째 붙여넣기가 앞 항목을 "원래 클립보드"로 저장한다 |
| `HoldItem` 에 필드를 더할 때는 옵셔널로 | 옛 `stack.json` 에 없는 키라서, 필수 필드면 저장된 스택 전체를 못 읽는다 |
| 목록 창에는 입력칸이 없다. 새 의문은 작성 창(`⌃⇧H`)에서만 만든다 | 목록에서 곧바로 의문을 적는 일이 없었다. 입력칸이 없어야 모든 키가 목록 조작이다 |
| 목록 창에서 처리하지 않은 보통 키는 삼킨다(`default: return plain`) | 받아 줄 입력칸이 없어서, 흘려보내면 글자를 누를 때마다 경고음이 난다. ⌘ 가 붙은 키는 메뉴 몫이라 내보낸다 |
| 숫자 키는 글자가 아니라 자판 자리(`keyCode`)로 읽는다 | 한글 입력기가 켜져 있어도 같은 자리가 같은 숫자다 |
| 작성 창과 고치기 입력칸은 여러 줄(`⇧⏎` 줄바꿈) | 작성 창은 줄이 늘면 `fitToContent` 로 창도 늘린다 |
| 초점을 줄 때 `moveCursorToEnd` | macOS 는 초점이 가면 글 전체를 선택해서, 살려 둔 초안이 다음 글자에 통째로 지워진다 |
| 패널 위치는 `setFrameAutosaveName("HoldStackPanel")` 이 저장한다 | 직접 저장 코드를 따로 두지 않는다 |
| 창을 띄우거나 초점을 줄 때마다 `placeOnActiveScreen` 을 거친다 | 저장된 자리만 믿으면 모니터가 여럿일 때 지난번 모니터에 계속 뜬다. 자리 저장은 그대로 두고 화면만 옮긴다 |
| AX 로 읽은 좌표는 y 를 뒤집어 쓴다 | AX 는 왼쪽 위가 원점이고 아래로 갈수록 y 가 크다. Cocoa 는 왼쪽 아래가 원점이라 안 뒤집으면 위아래로 놓인 모니터를 반대로 고른다 |
| `main.swift` 의 숨은 메인 메뉴를 지우지 않는다 | `.accessory` 앱은 이게 없으면 ⌘, 와 입력칸의 ⌘C ⌘V ⌘A 가 안 먹는다 |
| 작성 창이 떠 있을 때 hold 단축키는 포커스만 준다 | 다시 열면 쓰던 질문과 문장이 지워진다 |
| 창을 초점 잃음(`didResignKey`)으로 닫지 않는다. `FocusLossWatcher` 를 쓴다 | 데스크탑 전환도 초점을 뺏어서 이유를 구분할 수 없다. 설정이 이유별로 나뉜다 |
| 창을 띄울 때마다 `applySpaceBehavior` 로 데스크탑 동작을 정한다 | `canJoinAllSpaces` 로 두고 전환 뒤에 닫으면 새 데스크탑에 한 번 따라왔다가 사라져 깜빡인다. 닫을 거면 처음부터 `moveToActiveSpace` |
| 창 닫기 버튼은 `performClose` 를 덮어 `hide()` 로 보낸다 | 그냥 닫히면 키 모니터와 감시자가 남는다 |
| 설정 창 키 감시는 `ShortcutRecorder.attach` 하나뿐 | 녹화 취소 esc 와 창 닫기 esc 를 두 감시가 나눠 받으면 순서가 보장되지 않는다 |
| 창이 초점 잃음으로 내려가도 쓰던 글은 살린다 (`keepDraft`) | 목록 창과 작성 창 모두. 다시 열 때 비우지 않는다 |
| 창 위쪽 32pt 는 신호등 몫으로 비워 둔다. 거기에 뭘 그리지 않는다 | 제목 줄을 숨겨도 macOS 가 safe area 로 그만큼 떼어 둔다(`contentView.safeAreaInsets.top == 32`). 그 아래 머리글을 또 쌓으면 여백이 두 겹이 되고, `.ignoresSafeArea` 로 같은 줄에 올리면 제목 줄과 내용의 경계가 사라져 꼭대기에 붙어 보인다 |
| 첫 줄(탭)은 그 32pt 아래 `.padding(.top, 12)` | 더 좁으면 신호등에 눌려 보이고, 더 넓으면 창 위가 빈 땅이 된다. 40pt 와 58pt 를 다 써 보고 44pt 로 왔다 |
| 설정 뷰에 높이를 준다 | `Form` 은 스스로 높이가 없어 창이 제목 줄만 남는다 |
| 화면을 바꾸면 스크래치 패키지로 그려서 본다 | 뷰 파일을 심볼릭 링크한 별도 패키지에서 `cacheDisplay` 로 PNG 를 만든다. 앱 코드에 디버그 코드를 넣지 않는다 |
| 붙여넣기 전에 목록 창을 내린다 | 창이 초점을 쥐고 있으면 합성 ⌘V 가 창 자신으로 간다. 다시 띄울 때는 `orderFront`(초점 없이) |
| 스택과 휴지통을 바꾸는 길은 모두 `HoldStore` 의 공개 함수를 거친다 | 거기서 undo 기록을 남긴다. 건너뛰면 되돌릴 수 없다 |
| undo 기록은 `UndoOp`(removed, restored, purged, edited) 목록으로 `undo.json` 에 저장한다 | 메모리에만 두면 앱을 다시 켤 때 사라진다. 옛 형식 `[[UndoMark]]` 도 읽는다 |
| undo 기록을 미리 지우지 않는다. 되돌릴 때 대상이 없는 기록만 건너뛴다 | 미리 지우면 "지우기 → 되살리기 → 스택으로" 처럼 이어지는 되돌리기가 끊긴다 |
| 배포 빌드는 `--release` 로만 | 이 컴퓨터 인증서가 배포 파일에 들어가지 않게 한다 |
| 입력칸 판정은 "읽었는데 입력칸이 아닐 때만 막기" | 초점을 알려 주지 않는 앱에서 붙여넣기가 막히면 안 된다. `AXWebArea` 도 선택 범위를 가지므로 그것으로 가리지 않는다 |
| 붙여넣기 전에 우리 창이 키를 쥐는지 본다 (`NSApp.keyWindow`, 작성 창 표시 여부) | 비활성 패널은 앞 앱을 바꾸지 않은 채 키를 가져간다. 앞 앱의 초점만 보면 ⌘V 가 우리 창으로 가는 걸 놓친다 |
| 막을 때는 스택에서 빼기 전에 막는다 | 빼고 나서 막으면 의문이 휴지통으로 간다 |
| 목록 번호는 위에서부터 센다 (`index + 1`). 맨 위가 1번 | 숫자 키로 그 번호에 바로 가므로, 가장 자주 쓰는 맨 위가 가장 가까운 `1` 이어야 한다. 아래에서부터 세던 때는 새 항목이 들어와도 기존 번호가 안 밀리는 이점이 있었지만, 열 개가 넘으면 최신 항목에 가는 데 두 자리가 필요했다 |
| 고치기는 목록 창 안에서 그 자리에(`PanelModel.editingID`), 질문만. `HoldStore.update(id:text:)` 를 거친다. 고치는 중에는 방향키와 지우기가 입력칸 몫 | 문장은 원문 인용이라 바꾸면 원문과 어긋난다. 고친 것도 `.edited` 로 되돌린다 |
| 휴지통 개수는 `Preferences.trashLimit` → `HoldStore.trashLimit` | undo 기록 상한도 같은 값. 줄여도 즉시 자르지 않는다 |
| 화면 문구는 `L("한국어 원문")` 으로 쓰고 영어를 `Localization.swift` 표에 넣는다 | 설정에서 곧바로 언어를 바꾸려고 `.strings` 대신 코드 표를 쓴다. 값은 `L("…%d…", n)`. 추가한 뒤 `check-l10n.sh` |
| 로그에 클립보드 내용을 적지 않는다 | 개인 정보. 글자 수만 |
| 개인 정보를 넣지 않는다 | 배포용이다. 번들 ID 는 `app.holdstack.HoldStack`. 사람 이름, 계정, 절대 경로를 코드와 문서에 쓰지 않는다 |
| 순수 로직은 `HoldCore` 에 둔다 | 자동 검증이 되는 곳은 거기뿐이다 |
| `switch` 에서 `case A, B where cond` 금지 | `where` 가 B 에만 걸린다. `case A where cond, B where cond` |

## 자동 검증이 안 되는 것

전역 단축키, 패널 조작, 다른 앱에 붙여넣기는 사람이 확인한다. 합성 키 입력에 터미널의 손쉬운 사용 권한이 필요하기 때문이다.
변경 후 README 「사용법」 표의 키를 한 번씩 눌러본다. 붙여넣기 문제는 `~/Library/Logs/HoldStack.log` 의 `ax=` 와 `front=` 부터 본다. 설정 변경 후에는 새 조합이 곧바로 먹는지, 옛 조합이 풀렸는지 본다. 클립보드를 건드렸으면 이미지를 복사해 둔 채 ⌃⇧P 를 누르고 이미지가 남는지 본다.

`make-cert.sh` 인증서 없이 빌드하면 ad-hoc 서명이라 재빌드마다 손쉬운 사용 권한이 풀린다. 붙여넣기가 안 되면 로그의 `ax=` 부터 본다.
