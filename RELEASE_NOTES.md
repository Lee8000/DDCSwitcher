# DDC Switcher v1.0.0

通过全局组合快捷键切换显示器输入源的原生 macOS 菜单栏工具。

A native macOS menu-bar app for switching monitor inputs over DDC/CI with global keyboard shortcuts.

- Apple Silicon（M1 及以后）/ macOS 13+
- HDMI、DisplayPort、USB-C 预设与自定义输入代码
- 标准 DDC/CI 与 LG 兼容方式
- 全局快捷键录制、冲突检测、配置保存
- 无需 Homebrew；附带完整 MIT 开源源码与第三方许可

下载 `DDCSwitcher-macOS-arm64.zip`，解压后打开 `DDCSwitcher.app`。在显示器菜单中启用 DDC/CI，然后选择显示器、输入源及快捷键并保存。

本地软件验证：13 项 Swift 测试、4 个模拟 DDC 数据帧测试和 Carbon 集成自检通过。真实输入源切换及实体键盘全局触发仍需目标硬件验收。切到另一台电脑后能否切回取决于显示器是否保留非当前端口的 DDC 通路。

The application is ad-hoc signed, not Apple-notarized. Hardware switching and physical keyboard delivery require validation on your own setup. Successful command delivery does not confirm that the monitor changed inputs.
