# DDC Switcher：macOS 与 Windows 登录后自动启动

状态：用户已确认开发并发布。目标版本：v1.2.0。

## 用户体验

- 两个平台的设置窗口都增加全局复选框“登录后自动启动”，新安装默认关闭。
- 勾选或取消后立即修改当前用户的系统启动项，与快捷键配置的“保存”操作独立；失败时恢复实际状态并显示原因。
- 登录后启动应用、加载已保存快捷键，已有有效配置时驻留菜单栏或托盘。不会自动执行输入源切换。
- 每次打开设置时重新读取启动项状态。演示模式禁用该选项，不修改系统启动项。
- 旧版输入源与快捷键配置保持兼容，不需要重新配置。

## 原生实现（推荐）

macOS 使用 macOS 13 起提供的 ServiceManagement.SMAppService.mainApp 注册或取消登录项；显示“已启用”“需要系统批准”等真实状态，需要批准时提供系统登录项设置入口。应用应放在固定位置（建议“应用程序”）后启用。

Windows 使用当前用户 HKCU\Software\Microsoft\Windows\CurrentVersion\Run 中的 DDCSwitcher 项，无需管理员权限；保存带正确引号的完整程序路径，支持空格与中文，拒绝超出系统长度限制的启动命令。只修改本应用的启动项。界面说明：若在任务管理器禁用，需到系统启动应用设置重新启用；程序不绕过系统禁用状态。

取消勾选即撤销本应用注册的启动项。移动 Windows 程序后需在新位置关闭再开启该选项，以更新路径。

## 其他方案与取舍

1. macOS LaunchAgent 与 Windows 启动文件夹快捷方式：可行，但需要维护额外文件；macOS 已有原生登录项 API。
2. 提供手动设置说明或脚本：实现较少，但无法满足在应用内直接勾选的体验。

## 验证与交付

- 覆盖状态映射、启用/关闭、失败回滚、路径转义和旧配置兼容。
- Windows 原生测试使用隔离注册表测试项；macOS 自动测试使用替身，避免改变开发机器的实际登录项。
- 执行现有 macOS 与 Windows 构建和回归测试，进行独立代码审查。实际重启登录与显示器硬件行为仍需实机验证，发布说明如实注明范围。
- 更新两端使用说明，构建两个平台的安装包，沿用既有发布授权发布至 Lee8000/DDCSwitcher 的 v1.2.0。

## 技术依据

- Apple：SMAppService（已核对本机 macOS SDK 的 ServiceManagement/SMAppService.h）。
  https://developer.apple.com/documentation/servicemanagement/smappservice
- Microsoft：Run and RunOnce Registry Keys，当前用户 Run 项支持登录时启动；命令长度上限 260 字符。
  https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys
