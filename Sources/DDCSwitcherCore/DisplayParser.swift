import Foundation
public enum DisplayParser {
    public static func parse(_ output: String) throws -> [DisplayInfo] {
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let pattern = #"^\[\d+\] (.+) \(([0-9A-Fa-f-]{36})\)$"#
        let regex = try NSRegularExpression(pattern: pattern)
        var result = [DisplayInfo]()
        var seen = Set<String>()
        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("- ") { continue }
            let ns = line as NSString
            guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else {
                throw SwitcherError.message("无法识别显示器列表：\(line.prefix(180))")
            }
            let id = ns.substring(with: match.range(at: 2)).uppercased()
            guard UUID(uuidString: id) != nil, seen.insert(id).inserted else {
                throw SwitcherError.message("显示器标识无效或重复，无法安全选择目标。")
            }
            result.append(DisplayInfo(id: id, name: ns.substring(with: match.range(at: 1))))
        }
        guard !result.isEmpty else { throw SwitcherError.message("控制组件未返回有效的显示器列表。") }
        return result
    }
}
