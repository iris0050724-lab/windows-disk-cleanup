# 清理 / 迁移目标分类清单

## A. 可安全清理（白名单，仍建议先列清单）

| 位置 | 说明 |
|---|---|
| `%TEMP%`（`C:\Users\<user>\AppData\Local\Temp`） | 用户临时文件；仅清理未被占用的 |
| `C:\Windows\Temp` | 系统临时文件 |
| `C:\Windows\SoftwareDistribution\Download` | Windows 更新下载缓存 |
| `%LOCALAPPDATA%\Microsoft\Windows\INetCache` | IE / 系统组件的网络缓存 |
| `%LOCALAPPDATA%\CrashDumps` | 崩溃转储 |
| `%LOCALAPPDATA%\Microsoft\Windows\WER` | 错误报告 |
| `C:\$WinREAgent` | 系统升级后的残留（升级完成后可删） |
| `C:\$Windows.~BT` / `C:\$Windows.~WS` | 升级临时文件 |
| `%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db` | 缩略图缓存，会自动重建 |
| Delivery Optimization 缓存 | 传递优化缓存 |

## B. 需确认后可清理（程序残留）

**判定"程序确已卸载"的三重交叉验证：**

1. 注册表 `Uninstall` 下无对应项（`HKLM` / `HKCU` 两处都要看）。
2. 程序安装目录只剩 `uninst.exe` / `deleteSelf.bat` 之类的卸载器。
3. 开始菜单 / 桌面无对应快捷方式。

三项都满足 → 判定为残留数据目录。**仍需向用户确认后才能删。**

常见残留位置：`%APPDATA%\<厂商>`、`%LOCALAPPDATA%\<厂商>`、`C:\ProgramData\<厂商>`、`C:\Program Files (x86)\<厂商>`。

**注意**：注册表 `EstimatedSize` 与安装程序自报体积经常严重失真（实测某程序自报 1.14 GB，实际 4.95 GB）。**一律以目录实测字节数为准。**

## C. 适合迁移（复制 → Junction）

特征：体积大、可重建、软件按固定路径读写、非程序本体。

| 类别 | 典型位置 |
|---|---|
| 浏览器缓存 | `...\User Data\Default\Code Cache`、`...\Default\Cache` |
| IDE / 编辑器缓存 | `Code\CachedExtensionVSIXs`、各 IDE 的 `Cache` / `CachedData` |
| 通讯软件扩展 | `WeChat\XPlugin`、`xwechat\XPlugin` |
| 办公软件缓存 | `kingsoft\office6\cache` |
| 游戏平台 | `WeGame`、各启动器的下载缓存 |
| 设计工具 | `Figma\DesktopProfile` 等 |
| 云盘缓存 | 各网盘的本地缓存目录（**不含**未同步文件） |

**注意**：迁移前必须退出对应程序，否则文件持续写入导致校验不通过。Junction 不需要管理员权限。

## D. 禁止直接删除

见 `permissions-and-safety.md` 第六节。要点：`WinSxS`、`Windows\Installer`、`ProgramData\Package Cache`、`$Recycle.Bin`、`System Volume Information`、个人数据目录、运行中程序的安装目录。

`WinSxS` 与组件清理只能用系统工具：

```bat
DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /StartComponentCleanup
```
