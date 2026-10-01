import WidgetKit
import SwiftUI
import ActivityKit

@main
struct LustreLiveBundle: WidgetBundle {
    var body: some Widget {
        LXThinkingLive()
    }
}

/// 1001 她要的"正在想":她发完消息退到桌面,灵动岛和锁屏上显示"<名字> 正在想 0:42",回好了变成"回复了",点一下进那条线的对话。
/// 星芒和颜色照 App:footstar 缩小一份,星芒色白天月夜同一支浅蓝 #B6D6E8
struct LXThinkingLive: Widget {
    static let star = Color(red: 0xB6 / 255, green: 0xD6 / 255, blue: 0xE8 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LXLiveAttributes.self) { ctx in
            LXLiveLockView(state: ctx.state, name: ctx.attributes.name)
                .activityBackgroundTint(Color.black.opacity(0.62))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(Self.url(ctx.attributes.line))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        LXLiveStar(size: 18)
                        Text(ctx.attributes.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LXLiveClock(state: ctx.state)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(LXLiveLockView.line(ctx.state))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            } compactLeading: {
                LXLiveStar(size: 16)
            } compactTrailing: {
                LXLiveClock(state: ctx.state)
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: 46)
            } minimal: {
                LXLiveStar(size: 14)
            }
            .widgetURL(Self.url(ctx.attributes.line))
            .keylineTint(Self.star)
        }
    }

    /// 点一下进那条线:lustre://open?s=<线>,App 收到后跟点通知走同一条路
    static func url(_ line: String) -> URL? {
        var c = URLComponents()
        c.scheme = "lustre"
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "s", value: line)]
        return c.url
    }
}

/// 想了多久:时钟自己往上走,不用推送一秒一更;回好了换成"回复了"
struct LXLiveClock: View {
    let state: LXLiveAttributes.ContentState
    var body: some View {
        if state.phase == "replied" {
            Text("回复了").foregroundColor(LXThinkingLive.star)
        } else {
            Text(timerInterval: Date(timeIntervalSince1970: state.since)...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundColor(LXThinkingLive.star)
        }
    }
}

struct LXLiveStar: View {
    let size: CGFloat
    var body: some View {
        if let img = UIImage(named: "livestar") {
            Image(uiImage: img)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(LXThinkingLive.star)
        } else {
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.8, weight: .semibold))
                .foregroundColor(LXThinkingLive.star)
        }
    }
}

struct LXLiveLockView: View {
    let state: LXLiveAttributes.ContentState
    let name: String

    static func line(_ s: LXLiveAttributes.ContentState) -> String {
        s.phase == "replied" ? "回复了，点开看" : "正在想…"
    }

    var body: some View {
        HStack(spacing: 12) {
            LXLiveStar(size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(Self.line(state))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer(minLength: 8)
            LXLiveClock(state: state)
                .font(.system(size: 17, weight: .medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
