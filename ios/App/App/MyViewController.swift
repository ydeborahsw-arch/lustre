import UIKit
import Capacitor

class MyViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        let bgHex = ["day": 0xFBFDFE, "half": 0x191917][RPSpec.moonState] ?? 0x000000
        let bg = UIColor(red: CGFloat((bgHex >> 16) & 255) / 255, green: CGFloat((bgHex >> 8) & 255) / 255,
                         blue: CGFloat(bgHex & 255) / 255, alpha: 1)
        view.backgroundColor = bg
        bridge?.webView?.backgroundColor = bg
        let healthPlug = HealthPlugin()
        let devicePlug = DevicePlugin()
        bridge?.registerPluginInstance(healthPlug)
        bridge?.registerPluginInstance(devicePlug)
        if LustreConfig.webless { LXVitalsLoop.shared.start(health: healthPlug, device: devicePlug) }
        bridge?.registerPluginInstance(PickerPlugin())
        bridge?.registerPluginInstance(ExtraPlugin())
        let inputPlug = NativeInputPlugin()
        bridge?.registerPluginInstance(inputPlug)
        let chatPlug = ChatListPlugin()
        bridge?.registerPluginInstance(chatPlug)
        let homePlug = HomePlugin()
        bridge?.registerPluginInstance(homePlug)
        bridge?.registerPluginInstance(DrawerPlugin())
        bridge?.registerPluginInstance(SysPlugin())
        bridge?.registerPluginInstance(CallKitPlugin())
        // 0926 每次开机都把当前月相的调色板写进 Home 缓存(以前只在缓存空的时候写:
        // 新包改了颜色,Home 要等切一次月相才跟上)
        if LustreConfig.webless {
            LXMoonPalette.persist(RPSpec.moonState)
        }
        if let host = view {
            let cached = UserDefaults.standard.dictionary(forKey: HomePlugin.themeCacheKey) ?? [:]
            homePlug.attachEarly(host: host, payload: cached)
        }
        if LustreConfig.webless {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak chatPlug, weak inputPlug] in
                chatPlug?.attachEarly()
                inputPlug?.cardBootNative()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { QuickAction.deliver() }

        bridge?.webView?.tintColor = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
        ImeLine.install()
        if ImeLine.mode != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                ImeLine.apply(ImeLine.mode, on: self?.bridge?.webView)
            }
        }
    }
}
