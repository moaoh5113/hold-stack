import HoldCore
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.mainMenu = makeMainMenu(settingsTarget: delegate)
app.run()

/// 메뉴 막대는 보이지 않지만, 이게 있어야 ⌘, 와 입력칸의 ⌘C ⌘V ⌘A ⌘Z 가 먹는다.
func makeMainMenu(settingsTarget: AppDelegate) -> NSMenu {
    let appMenu = NSMenu(title: "HoldStack")
    let settings = appMenu.addItem(withTitle: L("설정…"), action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
    settings.target = settingsTarget

    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    edit.addItem(.separator())
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    let editItem = NSMenuItem()
    editItem.submenu = edit
    let main = NSMenu()
    let appItem = NSMenuItem()
    appItem.submenu = appMenu
    main.addItem(appItem)
    main.addItem(editItem)
    return main
}
