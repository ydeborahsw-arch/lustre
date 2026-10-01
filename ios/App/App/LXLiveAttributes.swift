import Foundation
import ActivityKit

/// 1001 她要的"正在想":她不在 App 时某条线在想,灵动岛和锁屏上亮一条,回好了变成"回复了"。
/// App 和灵动岛小部件共用这一份。relay 推起/更新时 attributes-type 写这个类型名,字段名也要一一对上
@available(iOS 16.1, *)
struct LXLiveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "thinking" 正在想 / "replied" 回复了
        var phase: String
        /// 开始想的时刻,Unix 秒。不用 Date:推送里的 JSON 解出来会按 2001 年起算
        var since: Double
    }
    /// 哪条线:""=主线,"yan-main"=他
    var line: String
    /// 显示的名字(relay 按备注填)
    var name: String
}
