# BingWallpaperSilent

每天开机后静默下载 Bing 每日壁纸（4K）并自动设置为 Windows 桌面背景，全过程无窗口闪烁、无需人工干预。

## 功能

- 从 Bing 官方接口 `HPImageArchive.aspx` 获取当日壁纸信息（`mkt=zh-CN`，UHD 3840×2160）
- 下载到 `图片\BingWallpapers\`，文件名格式为 `20260810_壁纸标题.jpg`
- 调用 Win32 API `SystemParametersInfo(SPI_SETDESKWALLPAPER)` 立即生效，并写入注册表持久化
- 自动清理，仅保留最近 30 张壁纸
- 已存在的当日壁纸不重复下载
- 全程写日志到 `%LOCALAPPDATA%\BingWallpaperSilent\run.log`

## 文件说明

| 文件 | 作用 |
| --- | --- |
| [BingWallpaperSilent.ps1](BingWallpaperSilent.ps1) | 核心脚本：下载壁纸并设置桌面背景 |
| [RunBingWallpaperSilent.vbs](RunBingWallpaperSilent.vbs) | 静默启动器，用 `WScript.Shell.Run(cmd, 0, False)` 隐藏 PowerShell 窗口 |
| [自动bing壁纸.xml](自动bing壁纸.xml) | 计划任务导出文件（UTF-16 编码），登录后延迟 30 秒触发 |

之所以多一层 VBS，是因为直接用计划任务调用 `powershell.exe` 即使加了 `-WindowStyle Hidden` 也会有一瞬间的黑框闪烁；VBS 的 `Run` 方法第二个参数传 `0` 才能做到完全无窗口。

## 安装

### 1. 放置脚本

把仓库克隆或解压到任意目录，例如 `C:\Users\<你的用户名>\Documents\自动bing壁纸`。

### 2. 手动测试一次

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BingWallpaperSilent.ps1
```

看到壁纸变化即为成功。失败时查看日志：

```powershell
Get-Content "$env:LOCALAPPDATA\BingWallpaperSilent\run.log" -Tail 20
```

### 3. 创建计划任务

**方式 A：命令行创建（推荐，无需改 XML）**

```powershell
$vbs = "$PWD\RunBingWallpaperSilent.vbs"
$action    = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbs`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT30S"
$settings  = New-ScheduledTaskSettingsSet -DisallowStartIfOnBatteries:$false -StopIfGoingOnBatteries:$false
Register-ScheduledTask -TaskName "自动bing壁纸" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest
```

**方式 B：导入 XML**

`自动bing壁纸.xml` 里有两处是**机器相关**的，导入前必须改：

- `<UserId>` —— 原机器的 SID，改成你自己的（`whoami /user` 可查），或直接改成 `DOMAIN\Username` 形式
- `<Arguments>` —— 改成你本机 `RunBingWallpaperSilent.vbs` 的完整路径

然后导入：

```powershell
Register-ScheduledTask -Xml (Get-Content .\自动bing壁纸.xml -Raw -Encoding Unicode) -TaskName "自动bing壁纸"
```

> 注意该 XML 是 UTF-16 编码，读取时要带 `-Encoding Unicode`，否则会报格式错误。

## 计划任务配置要点

- **触发器**：登录时触发，延迟 30 秒（等网络就绪）
- **多实例策略**：`IgnoreNew`，避免重复运行
- **电池设置**：默认导出的 XML 里 `DisallowStartIfOnBatteries` 为 `true`，笔记本用电池时不会执行，需要的话改成 `false`
- **RunLevel**：`HighestAvailable`

## 自定义

改 `BingWallpaperSilent.ps1` 顶部的 `$jsonUrl` 即可调整：

| 参数 | 说明 |
| --- | --- |
| `idx=0` | `0` 今天，`1` 昨天，最大 `7` |
| `n=1` | 返回几张 |
| `mkt=zh-CN` | 地区，可改 `en-US`、`ja-JP` 等 |
| `uhdwidth` / `uhdheight` | 分辨率，按屏幕改，如 `2560×1440` |

保留张数在脚本末尾的 `Select-Object -Skip 30` 处修改。

## 卸载

```powershell
Unregister-ScheduledTask -TaskName "自动bing壁纸" -Confirm:$false
Remove-Item "$env:LOCALAPPDATA\BingWallpaperSilent" -Recurse -Force
```

下载的壁纸在 `图片\BingWallpapers\`，按需自行删除。

## 环境要求

- Windows 10 / 11
- Windows PowerShell 5.1（系统自带，无需额外安装）
- 可访问 `www.bing.com`
