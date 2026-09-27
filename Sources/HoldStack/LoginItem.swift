import ServiceManagement

/// 로그인 시 자동 실행. 상태는 macOS 가 가지고 있어서 매번 물어본다.
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var message: String?

    func set(_ on: Bool) {
        do {
            try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            message = SMAppService.mainApp.status == .requiresApproval
                ? "시스템 설정 → 일반 → 로그인 항목에서 허용해 주세요" : nil
        } catch {
            message = "바꾸지 못했습니다: \(error.localizedDescription)"
        }
        enabled = SMAppService.mainApp.status == .enabled
    }
}
