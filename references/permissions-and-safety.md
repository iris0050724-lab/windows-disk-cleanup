# 权限、删除安全与确认流程

## 一、确认流程（硬性要求）

**任何删除或移动之前，必须完成：**

1. 列出每一个具体路径 + 实测体积 + 处理原因（删除 / 迁移 / 保留）。
2. 明确标注每一项属于：`白名单可清理` / `需用户确认` / `个人数据不主动处理`。
3. 把清单交给用户，等待用户**逐项或整体明确回复**。
4. 用户没有点到的项，**一律不动**。

**严禁**：

- 未经确认批量删除。
- 自行判断"这个看起来像垃圾"就删。
- 在替他人清理时跳过确认（必须让机器所有者确认）。

## 二、文件属主与权限

Windows 某些目录属主是 `BUILTIN\Administrators`，普通用户 ACL 只有 `ReadAndExecute`，删除时报"访问被拒绝"。

**处理方式（需管理员）：**

```bat
takeown /F "<dir>" /R /D Y
icacls "<dir>" /grant "*S-1-5-32-544":F /T /C      :: Administrators
icacls "<dir>" /grant "%USERNAME%":F /T /C          :: 当前用户
rmdir /S /Q "<dir>"
```

**当前进程无管理员权限时**：不要反复重试、不要强删。把这类操作写进 `cleanup_admin.bat`，交付用户右键"以管理员身份运行"。

判断是否管理员：

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

## 三、删除 ≠ 释放空间

Windows 上删除文件默认进入**回收站**，磁盘空间不会立即释放。

- 删除后必须执行 `Clear-RecycleBin -DriveLetter C -Force` 才真正释放。
- 某些环境下删除会被安全软件 / 组策略钩子拦截并强制转投回收站，失败时报错并**拒绝硬删除**（fail-closed）。此时接受"删除 → 清空回收站"两步即可。
- 若整目录批量删除被拦，可改为**逐文件删除**（实测对小体量残留有效）。

## 四、批量删除阈值

部分环境对单轮删除的文件数量有限制（阈值约 50 个）。超过会报 `BULK_CONFIRM_REQUIRED` 之类的错误。

**做法**：分批处理，每批 ≤ 50 个文件，逐批校验。

## 五、迁移的可逆性

五步法迁移**天然可逆**：

- 目标数据保留在 `<TargetRoot>\<去掉盘符后的原路径>`。
- 还原：删除原位置的 Junction，再把目标目录复制回原路径即可。
- 因此迁移比删除安全得多。**当目标只是"腾空间"而数据仍有用时，优先迁移。**

## 六、不可触碰的禁区

| 对象 | 原因 |
|---|---|
| 桌面 / 下载 / 文档 / 图片 / 视频 | 个人数据，默认只读 |
| 通讯软件数据目录（微信、QQ、钉钉等） | 含聊天记录，删除不可逆 |
| 浏览器用户配置（`User Data`） | 含登录状态、书签、密码 |
| `C:\Windows\WinSxS` | 组件存储，只能用 `DISM /Online /Cleanup-Image /StartComponentCleanup` |
| `C:\Windows\Installer` | MSI 卸载 / 修复必需，删了无法卸载软件 |
| `C:\ProgramData\Package Cache` | 安装程序修复 / 卸载必需 |
| `$Recycle.Bin` 目录本身 | 应通过"清空回收站"操作，不要直接删目录 |
| `System Volume Information` | 系统还原点 |
| 仍在运行程序的安装目录 | 强删会留下更糟的注册表垃圾 |
| `.git` / 项目源码目录 | 即使看着像缓存也要先确认 |

## 七、备份先行

见 `backup-checklist.md`。清理前提醒用户备份关键数据是**强制步骤**，不是可选项。
