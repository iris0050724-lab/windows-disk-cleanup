# windows-disk-cleanup

> 一套面向 Windows 10 / 11 的磁盘空间清理与跨盘迁移技能（Agent Skill）。
> 把「先备份 → 只读体检 → 出报告 → 逐项确认 → 迁移 → 清理 → 管理员收尾」固化成可重复执行的流程，
> 并内置了 Windows 上最常见的一堆坑的确定性做法。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue)

---

## ⚠️ 重要警告与免责声明（请务必先读）

> **1. 清理前必须自行备份重要文件。**
> 本技能会执行**删除**与**移动**操作，可能造成数据**不可逆丢失**。
> **因使用本技能导致的重要文件丢失，作者与分发者不承担任何责任。**
>
> **2. 请至少备份以下内容**（详细清单见 [`references/backup-checklist.md`](references/backup-checklist.md)）：
> 登录凭据与账号信息（浏览器密码、Cookie、SSH 私钥、API Key）、密码管理器数据库、
> 聊天记录（微信 / QQ / 钉钉）、软件日志与崩溃转储、许可证与激活码、配置文件、
> 证书与密钥库、浏览器书签、本地邮件数据（.pst/.ost）、本地数据库、云盘未同步文件。
>
> **3. 备份要放在另一个盘上**（另一块硬盘 / 移动硬盘 / 云端），**不要**放在正要清理的同一个盘中。
>
> **4. 不得未经确认删除他人电脑上的数据。**
> 本技能强制「逐项列出 → 用户确认 → 才执行」。替他人清理时，必须由**机器所有者**确认每一行。
>
> **5. 本技能不保证清理后系统的稳定性**。请自行判断风险，重要机器请先做完整系统备份（镜像）。

---

## 这是什么

一个 **Agent Skill**（遵循开放的 `SKILL.md` 规范，可用于 WorkBuddy / Claude Code 等支持 Agent Skills 的宿主）。
安装后，当你说「帮我清理 C 盘」「C 盘快满了」「把大缓存搬到 D 盘」时，Agent 会自动加载本技能并按既定流程执行。

### 能力

| 能力 | 说明 |
|---|---|
| 只读空间体检 | 扫描各盘容量、根级目录构成、Top N 大目录与大文件 |
| 可视化报告 | 生成 HTML 体检报告，分「可直接清 / 建议迁移 / 需确认」三档 |
| 跨盘迁移 | 用目录联接（Junction）把缓存搬到其他盘，软件仍按原路径读写 |
| 安全清理 | 识别临时文件、更新缓存、程序残留，逐项确认后清理 |
| 管理员收尾 | 自动生成需提权的 `.bat`，处理属主为 Administrators 的目录与 HKLM 注册表 |
| 陷阱规避 | 内置回收站、权限、中文路径、体积统计等 Windows 专有问题的解法 |

### 不会做什么

- 不会在未经你确认的情况下删除或移动任何文件。
- 不会主动处理你的个人数据（桌面 / 下载 / 文档 / 图片 / 视频 / 聊天记录）。
- 不会触碰系统关键目录（`WinSxS`、`Windows\Installer`、`ProgramData\Package Cache` 等）。

---

## 适用环境

- Windows 10 / 11
- PowerShell 5.1 或更高（脚本为 ASCII 编写，兼容 5.1）
- 宿主支持 Agent Skills（WorkBuddy、Claude Code 等；或手工运行脚本）

---

## 目录结构

```
windows-disk-cleanup/
├── SKILL.md                          # 技能主文件（Agent 读取）
├── README.md                         # 本文件
├── LICENSE                           # MIT
├── scripts/
│   ├── disk_survey.ps1               # 只读空间体检
│   ├── folder_size.ps1               # 单目录体积统计（替代不可靠的 du）
│   ├── migrate_folder.ps1            # 五步法迁移 + 自动回滚
│   └── cleanup_admin.bat             # 需管理员权限的收尾操作模板
├── references/
│   ├── thresholds.md                 # 磁盘余量阈值与决策标准
│   ├── permissions-and-safety.md     # 权限、回收站、确认流程
│   ├── cleanup-targets.md            # 可清理 / 可迁移 / 禁止触碰清单
│   └── backup-checklist.md           # 备份关键数据核对表
└── assets/
    └── report-template.html          # 体检报告模板
```

---

## 安装

### 第 1 步：获取技能

方式 A —— Git 克隆（推荐，便于更新）：

```bash
git clone https://github.com/iris0050724-lab/windows-disk-cleanup.git
```

方式 B —— 下载 ZIP：在仓库页面点 **Code → Download ZIP**，解压得到 `windows-disk-cleanup/` 目录。

### 第 2 步：放到宿主的 skills 目录

技能目录名必须与 `SKILL.md` 里的 `name` 一致（即 `windows-disk-cleanup`）。

**WorkBuddy**

| 范围 | 放置路径 |
|---|---|
| 用户级（所有项目可用） | `C:\Users\<你的用户名>\.workbuddy\skills\windows-disk-cleanup\` |
| 项目级（仅当前项目） | `<项目目录>\.workbuddy\skills\windows-disk-cleanup\` |

**Claude Code**

```
C:\Users\<你的用户名>\.claude\skills\windows-disk-cleanup\
```

**其他宿主**：放进该宿主配置的 skills 搜索路径即可。

放置后的结构应为：

```
.workbuddy\skills\windows-disk-cleanup\SKILL.md      ← 必须能在这里找到 SKILL.md
.workbuddy\skills\windows-disk-cleanup\scripts\...
.workbuddy\skills\windows-disk-cleanup\references\...
```

### 第 3 步：验证安装

重启宿主（或重新打开会话），确认技能已被识别。常见宿主的技能列表里应出现 `windows-disk-cleanup`。

也可以直接手工验证脚本可用（不需要宿主）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\disk_survey.ps1 -OutFile "$env:TEMP\survey.txt"
Get-Content "$env:TEMP\survey.txt"
```

若出现执行策略报错，用 `-ExecutionPolicy Bypass`，或先执行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## 使用

### 在对话中触发

安装后直接用自然语言提出诉求即可，例如：

- 「帮我看看 C 盘为什么满了」
- 「清理 C 盘，把大缓存挪到 D 盘」
- 「哪些文件可以删？先给我个清单」
- 「C 盘只剩 8G 了，救一下」

Agent 会自动加载本技能并进入下面的流程。

### 完整流程

```
Phase 0  备份关键数据        ← 强制，先提醒并核对 backup-checklist
   ↓
Phase 1  只读体检            disk_survey.ps1（不做任何修改）
   ↓
Phase 2  出报告 + 等你决策    生成 HTML 报告，逐项列出清单
   ↓   「必须等你回复后才继续」
Phase 3  迁移                migrate_folder.ps1（复制→校验→删除→Junction）
   ↓
Phase 4  清理                按你确认过的清单删除
   ↓
Phase 5  管理员收尾          生成 cleanup_admin.bat，你右键以管理员运行
   ↓
        清空回收站            ← 不执行则空间不会真正释放
```

**关键：Phase 2 结束时 Agent 会停下来等你确认。** 它不会自作主张往下删。

### 手工使用（不依赖 Agent）

```powershell
# 1) 体检
.\scripts\disk_survey.ps1 -TopN 20 -MinSizeMB 500 -OutFile "$env:TEMP\survey.txt"
Get-Content "$env:TEMP\survey.txt"

# 2) 看某个目录到底多大
.\scripts\folder_size.ps1 -Path "C:\Users\me\AppData\Local\SomeApp","C:\ProgramData\Foo"

# 3) 试运行迁移（只校验不动作）
.\scripts\migrate_folder.ps1 -Source "C:\Users\me\AppData\Local\SomeApp\Cache" `
                             -TargetRoot "D:\CBak" -DryRun

# 4) 真正迁移（先退出对应程序！）
.\scripts\migrate_folder.ps1 -Source "C:\Users\me\AppData\Local\SomeApp\Cache" `
                             -TargetRoot "D:\CBak"

# 5) 清理后必须清空回收站，否则空间不释放
Clear-RecycleBin -DriveLetter C -Force
```

---

## 安全设计

| 设计 | 作用 |
|---|---|
| 只读优先 | 第一步永远是扫描 + 报告，不产生任何修改 |
| 逐项确认 | 删除 / 迁移前必须列出具体路径 + 体积 + 原因，等你明确回复 |
| 个人目录默认只读 | 桌面 / 下载 / 文档 / 图片 / 视频不主动处理 |
| 五步法 + 自动回滚 | 迁移校验（文件数 + 字节数）不通过就回滚，原目录不动 |
| 迁移可逆 | 数据保留在 `<目标盘>\<镜像路径>`，随时可还原 |
| 提权动作分离 | 需要管理员的操作单独生成 `.bat`，由你审阅后手动运行 |

### 如何还原一个已迁移的目录

```powershell
# 假设已把 C:\A\B 迁移到 D:\CBak\A\B
Remove-Item -LiteralPath "C:\A\B" -Force          # 删除 Junction（不会影响 D 盘数据）
Copy-Item -LiteralPath "D:\CBak\A\B" -Destination "C:\A\B" -Recurse -Force
```

---

## 常见问题

**Q：会不会把我重要的文件删了？**
A：不会在未确认的情况下删。技能强制「列清单 → 等确认」，个人目录默认只读。但**仍请自行备份**，这是硬性要求。

**Q：迁移后软件还能正常用吗？**
A：能。迁移用的是目录联接（Junction），原路径仍然可读可写，只是数据实际存放在另一个盘。

**Q：为什么删了文件但空间没变？**
A：Windows 删除默认进回收站。需要执行 `Clear-RecycleBin -DriveLetter C -Force`。

**Q：某些目录删不掉，报「访问被拒绝」？**
A：属主是 `BUILTIN\Administrators`。用管理员脚本里的 `takeown` + `icacls` 处理。

**Q：`du` 在 Git Bash 里显示 0？**
A：Windows 上用 `folder_size.ps1` 或 PowerShell 的 `Measure-Object` 统计。

**Q：脚本是乱码 / 报错？**
A：脚本刻意只用 ASCII 编写，以兼容 PowerShell 5.1。若你的编辑器保存时改了编码，请保持 UTF-8 或 ANSI。

**Q：能用于别人的电脑吗？**
A：可以，但**必须由机器所有者确认每一行清单**，且必须先提醒对方备份。

---

## 卸载

删除对应的技能目录即可：

```
C:\Users\<你的用户名>\.workbuddy\skills\windows-disk-cleanup\
```

已迁移的目录不会自动还原，需要时按上面「如何还原」手动处理。

---

## 贡献

欢迎提交 Issue / PR。新增清理目标时请同步更新：
- `references/cleanup-targets.md`（分类清单）
- `scripts/cleanup_admin.bat`（若涉及提权）

## 许可证

[MIT](LICENSE)

## 免责声明

本项目按「现状」提供，不附带任何明示或暗示的保证。使用者需自行承担因使用本项目而产生的全部风险与后果，包括但不限于数据丢失、系统损坏。作者与贡献者对任何直接或间接损失不承担责任。
