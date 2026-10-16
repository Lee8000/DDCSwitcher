# DDC Switcher · 显示器输入源快捷切换

A native macOS menu-bar app for switching monitor inputs over DDC/CI with global keyboard shortcuts. Apple Silicon · macOS 13+ · MIT.

English: [README.en.md](README.en.md)

原生桌面工具：macOS 菜单栏版与 Windows 系统托盘版。为 HDMI、DisplayPort、USB-C 等输入源设置全局组合快捷键，也可直接从菜单选择输入源。

| 平台 | 系统要求 | 使用说明 |
| --- | --- | --- |
| Windows | Windows 10/11 x64 | [Windows 版说明](windows/README.md) |
| macOS | macOS 13+、Apple Silicon | 下方说明 |

Windows 版无需额外运行时。macOS 与 Windows 各自保存显示器及快捷键配置。

适用：**Apple Silicon（M1 及以后）Mac，macOS 13 或更新版本**。已验证的本地构建与软件测试环境为 Apple M4 / macOS 26.6.2。需要支持 DDC/CI 的外接显示器和能传递 DDC 信号的连接方式。无需 Homebrew、Python、辅助功能权限或屏幕录制权限。

## 下载

前往 [GitHub Releases](https://github.com/Lee8000/DDCSwitcher/releases/latest) 下载对应平台版本：

- [Windows x64](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.1.0/DDCSwitcher-v1.1.0-windows-x64.zip)
- [macOS Apple Silicon](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.1.0/DDCSwitcher-v1.1.0-macOS-arm64.zip)

## macOS 开始使用

1. 解压应用包，把 `DDCSwitcher.app` 放在“应用程序”或你希望长期保存的位置，然后双击打开。
2. 在显示器自己的菜单中打开 **DDC/CI**。连接显示器后，在应用设置中点击“刷新显示器”。
3. 点击“＋ 添加”，选择目标显示器及输入源，例如“工作电脑 · HDMI 1”。
4. 点击快捷键按钮，按下组合键，例如 **⌃⌥⌘1**。快捷键需包含 Command（⌘）或 Control（⌃），按 Esc 可取消录制。
5. 点击“保存并启用”。也可以点击“保存并切换此动作”，立即发送一次切换命令。
6. 为另一个输入源再建一个动作，例如 USB-C → **⌃⌥⌘2**。

关闭设置窗口后，应用继续在菜单栏运行。点击显示器图标可切换输入源、打开设置或退出。退出后快捷键释放。第一次运行没有预设快捷键，也不会自动切换显示器。

若希望登录后启动，可在“系统设置 → 通用 → 登录项与扩展”中自行添加此应用。应用不会自动修改登录项。

本地构建采用临时签名，未使用 Apple Developer ID 公证。若 macOS 拦截你确认来源的应用，可在尝试打开后进入“系统设置 → 隐私与安全性”中使用系统提供的打开选项。本项目不要求关闭 Gatekeeper。

## 输入源代码

设置中的下拉菜单提供这些常见值；**它们不保证适用于每个型号**。具体型号可使用自定义十进制代码（0–65535）。

| 输入源 | 标准 DDC/CI | LG 兼容方式 |
| --- | ---: | ---: |
| DisplayPort 1 | 15 | 208 |
| DisplayPort 2 | 16 | 209 |
| HDMI 1 | 17 | 144 |
| HDMI 2 | 18 | 145 |
| USB-C / DP 3 | 27 | 210 |

先选择控制方式，再选对应输入源预设。改变控制方式不会擅自改写输入代码；请重新选择预设或填写自定义代码。USB-C 可能在显示器固件中被当作 DisplayPort，需以实机结果为准。

## 切换前需要知道

- **切到另一台电脑后，原 Mac 可能无法再切回。** 有的显示器会断开非当前输入端口的视频链路或 DDC 通路；这时只能通过显示器按键、遥控器或另一台电脑发命令切回。该工具不能跨越已断开的连接。
- “切换命令已发送”表示控制组件成功完成写入。DDC 写命令通常没有可靠的输入切换确认；是否生效请观察显示器。
- 列出显示器只说明系统能枚举到它，不代表线材、扩展坞或显示器一定允许 DDC 控制。无效时可尝试直连 USB-C / DisplayPort、其他线材，以及显示器的其他输入代码。
- 采用每个输入源一个快捷键，不依赖显示器回报当前输入。按键按照物理键位保存；某些功能键需要同时按 Fn。
- 快捷键冲突会在保存时提示；保存失败会保留原有设置和注册。某些前台应用或系统保留组合可能拦截按键，请换组合键测试。
- 同一时间只发一个切换动作，并抑制短时间连续触发。显示器断开后拒绝执行，不会自动改为操作其他显示器。
- 设置仅保存在 `~/Library/Application Support/DDCSwitcher/settings.json`。损坏文件不会被静默覆盖，可用设置窗口中的备份重置按钮恢复。更新应用后设置仍会保留。
- 卸载时先从菜单栏退出，再移走应用。若不再需要配置，可手动移走上述设置文件夹及自行添加的登录项。

## 从源码构建

需要 Xcode 或 Apple Command Line Tools（Swift、clang、make、codesign、iconutil）。无外部 Swift 包依赖，m1ddc 源码与许可证已包含。

```sh
bash scripts/test.sh
bash scripts/build.sh
open dist/DDCSwitcher.app
```

产物：`dist/DDCSwitcher.app`。脚本只在项目内创建构建缓存与产物。构建目标为 arm64，最低部署版本为 macOS 13。

完整集成自检（需要已登录的 macOS 图形会话）：

```sh
bash scripts/test.sh --integration
```

自检注册临时全局热键，并通过 Carbon 事件到模拟 DDC 后端验证完整流程，不发送真实 DDC 写入。

安全的界面演示模式（模拟显示器，配置与命令日志写入指定文件夹）：

```sh
open dist/DDCSwitcher.app --args --demo "$PWD/.build/demo"
```

演示模式窗口明确标注“不控制硬件”。退出演示应用后，正常双击应用即可控制真实显示器。

## 验证范围与许可

见 `docs/VERIFICATION.md`。真实显示器输入切换仍需在目标显示器上完成验收。

主程序使用 MIT 许可证，见 `LICENSE`；第三方声明见 `THIRD_PARTY.md`。m1ddc 的官方源码与接口说明：https://github.com/waydabber/m1ddc
