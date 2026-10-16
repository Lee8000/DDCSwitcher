# DDC Switcher for Windows

Windows 10/11 **x64** 原生系统托盘工具。解压即可运行，无需额外安装 .NET、Python 或 Visual C++ 运行时，无需管理员权限。通过标准 DDC/CI 输入选择命令控制外接显示器。

## 使用

1. 在显示器自身菜单中启用 **DDC/CI**，连接 Windows 电脑。
2. 双击 `DDCSwitcher.exe`，点击“刷新显示器”。建议使用直连和扩展显示模式。
3. 点击“＋ 添加”，选择显示器、输入源预设或自定义十进制代码。
4. 点击快捷键按钮，按下例如 **Ctrl+Alt+1**；按 Esc 取消。至少包含 Ctrl 或 Alt，可搭配 Shift。F12 为 Windows 调试器保留。
5. 点击“保存并启用”。也可点击“保存并切换此动作”，立即发送一次命令。
6. 为其他输入源添加不同快捷键，例如 USB-C → Ctrl+Alt+2。

关闭设置窗口后程序继续在系统托盘运行。双击托盘图标打开设置，右击可选择输入动作或退出。Windows 可能把图标收在托盘的隐藏图标区。退出程序后快捷键释放。

首次启动没有默认切换动作或已注册快捷键。“登录后自动启动”默认关闭，勾选或取消立即生效，无需保存动作。登录后加载已有快捷键并驻留托盘，不会自动切换输入源。

自启动仅影响当前用户，使用 Windows 的 Run 启动项，无需管理员权限。请先把解压文件夹放在固定位置，再启用；移动程序后需关闭再开启该选项来更新路径。系统可能延迟启动。复选框显示本应用启动项是否已注册；如果在任务管理器禁用，还需到“设置 → 应用 → 启动”重新允许，应用不会绕过系统禁用。演示模式禁用该选项。

## 输入代码和连接限制

常见代码：DP 1 = 15、DP 2 = 16、HDMI 1 = 17、HDMI 2 = 18、USB-C = 27。**不同型号可能使用其他值，预设不是能力检测结果。** 自定义范围为 0–65535。

Windows 版使用系统 Dxva2 `SetVCPFeature` 的标准输入选择接口。它不提供 macOS 版 LG 特殊 I2C 目的地址控制；不能假设 macOS 的 LG 兼容模式在此版本等价可用。

显示器身份绑定使用 Windows 设备路径。目标不在线或映射不唯一时会拒绝控制，不会根据 DISPLAY1 之类的临时编号猜测目标。镜像模式、多物理设备映射或部分虚拟显示设备可能无法使用；尝试扩展模式和直连。

“命令已发送”只代表系统接口返回成功，不代表显示器已经确认完成切换。切至另一台电脑后，原端口可能断开 DDC，届时需用显示器按键或另一台电脑切回。

驱动调用在独立进程执行，超时后终止；界面不会等待驱动无限挂起。仅串行执行切换，并抑制持续按键重复。

## 设置与卸载

设置在 `%LOCALAPPDATA%\DDCSwitcher\settings.txt`，为带版本号的 UTF-8 文本，与 macOS 配置分别保存。保存失败保留原设置和快捷键。无法解析的文件不会静默覆盖，可从界面“备份并重置损坏设置”恢复。

卸载时先取消“登录后自动启动”，再从托盘退出并删除解压文件夹。若不再需要配置，可手动删除上述设置目录。

应用未进行商业 Authenticode 签名。Windows 可能提示发布者未知；仅在确认下载来源为本仓库 Release 且校验一致后，使用系统提供的运行选项，不需要关闭系统安全保护。

## 构建与测试

Windows 安装 Visual Studio 2022 或更新版本的 C++ 桌面开发工具，以及 CMake。无需下载第三方源码。

```powershell
.\windows\scripts\build.ps1
.\windows\scripts\test.ps1
.\windows\scripts\package.ps1
```

请在允许运行本地开发脚本的 PowerShell 环境中执行这些命令。

产物：`windows/build/Release/DDCSwitcher.exe`，分发包：`windows/dist/DDCSwitcher-windows-x64.zip`。

测试包括隔离 HKCU 测试项中的自启动注册/取消/路径与失败检查（不修改实际 Run 项）、可移植核心检查、实际原子文件保存/损坏保护、模拟后端子进程成功/失败/超时和 RegisterHotKey / WM_HOTKEY 消息分发；**不发送真实 DDC 输入切换，也不合成实体键盘输入**。真实设备、驱动和键盘组合需实机验收。

演示模式：

```powershell
.\DDCSwitcher.exe --demo
```

演示模式只显示虚拟显示器，配置写入独立的 `%LOCALAPPDATA%\DDCSwitcherDemo`，窗口明确标注“不控制硬件”。退出演示实例后，正常打开即可配置真实显示器。

在其他平台运行核心测试：

```sh
cmake -S windows -B windows/build-local
cmake --build windows/build-local
ctest --test-dir windows/build-local --output-on-failure
```

Mac 上使用 MinGW-w64 交叉编译（只能编译，无法代替 Windows 原生运行验证）：

```sh
cmake -S windows -B windows/build-cross -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres -DCMAKE_BUILD_TYPE=Release
cmake --build windows/build-cross --parallel
```

## English quick start

Portable native Windows 10/11 x64 tray application. Extract and run `DDCSwitcher.exe`; no additional runtime or administrator privileges are required. Enable DDC/CI on the monitor, refresh, add an action, select its monitor/input, record a Ctrl/Alt shortcut and save. Close the window to keep the app in the tray; right-click the tray icon to switch or quit.

Enable the optional “登录后自动启动” checkbox to launch at login; it is off by default and applies immediately for the current user. Keep the executable at a fixed location; after moving it, turn the option off and on. If disabled in Task Manager, re-enable it in Windows Startup Apps. Disable it before uninstalling. Demo mode never changes startup registration.

Settings: `%LOCALAPPDATA%\DDCSwitcher\settings.txt`. Demo mode uses a separate `DDCSwitcherDemo` folder. The app uses standard Windows DDC/CI; LG alternate addressing from the macOS helper is not equivalent. Ambiguous/mirrored monitor mappings are refused. Command delivery does not confirm physical switching, and inactive inputs may stop accepting DDC commands.

GitHub Windows CI builds with a static MSVC runtime and runs core/native simulated tests. Physical keyboard delivery and real monitor switching require testing on your hardware. Builds are not Authenticode-signed. This application is MIT licensed; macOS-only third-party code is described in the repository notices.
