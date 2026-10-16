# DDC Switcher v1.1.0

新增原生 **Windows 10/11 x64 系统托盘版**，解压运行，无需额外运行时。macOS 菜单栏版继续提供。

A native Windows tray and macOS menu-bar app for switching monitor inputs over DDC/CI with global keyboard shortcuts.

- Windows 10/11 x64；macOS 13+ / Apple Silicon（M1 及以后）
- HDMI、DisplayPort、USB-C 预设与自定义输入代码
- Windows 标准 DDC/CI；macOS 标准 DDC/CI 与 LG 兼容方式
- 全局快捷键录制、冲突检测、配置保存
- 无需 Homebrew；附带完整 MIT 开源源码与第三方许可

Windows 下载 `DDCSwitcher-v1.1.0-windows-x64.zip`，解压后打开 `DDCSwitcher.exe`；macOS 下载 `DDCSwitcher-v1.1.0-macOS-arm64.zip`，打开 `DDCSwitcher.app`。

在显示器菜单中启用 DDC/CI，然后添加动作、选择显示器与输入源、录制快捷键并保存。Windows 建议 Ctrl+Alt+1 / Ctrl+Alt+2，关闭窗口后程序继续在系统托盘运行。

软件验证：Windows 33 项核心检查、14 项原生检查及 MSVC 构建通过；macOS 13 项 Swift 测试、4 个模拟 DDC 数据帧测试及构建通过，既有 Carbon 集成自检已通过。真实输入源切换及实体键盘全局触发仍需目标硬件验收。切到另一台电脑后能否切回取决于显示器是否保留非当前端口的 DDC 通路。

Windows builds are not Authenticode-signed; macOS builds are ad-hoc signed, not Apple-notarized. Hardware switching and physical keyboard delivery require validation on your own setup. Successful command delivery does not confirm that the monitor changed inputs. The Windows app uses standard DDC/CI, without the macOS helper's LG alternate I2C addressing.
