import AppKit
import Carbon
import DDCSwitcherCore

func shortcutText(_ shortcut: Shortcut?) -> String {
    guard let s = shortcut else { return "未设置快捷键" }
    let symbols: [(UInt32, String)] = [(4096, "⌃"), (2048, "⌥"), (512, "⇧"), (256, "⌘")]
    let keys: [UInt32: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
        12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",
        24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",
        36:"↩",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",
        48:"⇥",49:"空格",50:"`",51:"⌫",53:"⎋",65:"数字键盘 .",67:"数字键盘 *",69:"数字键盘 +",
        64:"F17",71:"Clear",75:"数字键盘 /",76:"数字键盘 ↩",78:"数字键盘 −",79:"F18",80:"F19",81:"数字键盘 =",90:"F20",
        82:"数字键盘 0",83:"数字键盘 1",84:"数字键盘 2",85:"数字键盘 3",86:"数字键盘 4",
        87:"数字键盘 5",88:"数字键盘 6",89:"数字键盘 7",91:"数字键盘 8",92:"数字键盘 9",
        96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",105:"F13",106:"F16",
        107:"F14",109:"F10",111:"F12",113:"F15",114:"Help",115:"Home",116:"Page Up",
        117:"⌦",118:"F4",119:"End",120:"F2",121:"Page Down",122:"F1",123:"←",124:"→",125:"↓",126:"↑"
    ]
    return symbols.filter { s.modifiers & $0.0 != 0 }.map(\.1).joined() + (keys[s.keyCode] ?? "键 \(s.keyCode)")
}

final class HotKeyManager {
    private struct Registration { let ref: EventHotKeyRef; let id: UInt32 }
    private var registrations: [Shortcut: Registration] = [:]
    private var actionIDs: [UInt32: UUID] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1
    private var desired: [SwitchAction] = []
    private var suspended = false
    var onTrigger: ((UUID) -> Void)?
    var onError: ((String) -> Void)?
    private let signature: OSType = 0x44444353 // DDCS

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            var hotkey = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkey)
            guard result == noErr, hotkey.signature == manager.signature,
                  let id = manager.actionIDs[hotkey.id] else { return OSStatus(eventNotHandledErr) }
            manager.onTrigger?(id)
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status != noErr { installationError = "无法安装全局快捷键处理器（\(status)）。" }
    }
    private var installationError: String?

    // Keep old registrations until all new combinations have been reserved.
    func replace(with actions: [SwitchAction], commit: () throws -> Void = {}) throws {
        try Configuration(actions: actions).validate()
        if let installationError { throw SwitcherError.message(installationError) }
        guard !suspended else { throw SwitcherError.message("请先结束快捷键录制。") }
        var staged = [Shortcut: Registration]()
        var mapping = [UInt32: UUID]()
        do {
            for action in actions where action.enabled {
                guard let shortcut = action.shortcut else { continue }
                let registration: Registration
                if let existing = registrations[shortcut] { registration = existing }
                else {
                    var ref: EventHotKeyRef?
                    let id = nextID; nextID &+= 1
                    let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                        EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &ref)
                    guard status == noErr, let ref else {
                        throw SwitcherError.message("无法注册 \(shortcutText(shortcut))（错误 \(status)）。它可能已被系统或其他应用占用，请换一个组合键。")
                    }
                    registration = Registration(ref: ref, id: id)
                    staged[shortcut] = registration
                }
                mapping[registration.id] = action.id
            }
            try commit()
        } catch {
            for entry in staged.values { UnregisterEventHotKey(entry.ref) }
            throw error
        }
        let wanted = Set(actions.filter(\.enabled).compactMap(\.shortcut))
        for (key, entry) in registrations where !wanted.contains(key) { UnregisterEventHotKey(entry.ref) }
        registrations = registrations.filter { wanted.contains($0.key) }.merging(staged) { _, new in new }
        actionIDs = mapping
        desired = actions
    }

    func setRecording(_ recording: Bool) {
        guard suspended != recording else { return }
        suspended = recording
        if recording {
            for entry in registrations.values { UnregisterEventHotKey(entry.ref) }
            registrations.removeAll(); actionIDs.removeAll()
        } else {
            do { try replace(with: desired) } catch { onError?(error.localizedDescription) }
        }
    }

    deinit {
        for entry in registrations.values { UnregisterEventHotKey(entry.ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
