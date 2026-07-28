# Vendor 字体：assets/fonts/ 里为什么放了这几个字体文件

2026-07-28 起，`assets/fonts/` 收了 6 个字体文件，随仓库一起 `git clone`；配 Windows 专用的
`scripts/install-fonts.ps1` 装进当前用户（不需要管理员）。

## 为什么

`lisp/init-ui.el` 的字体选择一直是"开机探测系统字体，找到第一个装了的就用，都没有就沉默
跳过用 Emacs 默认"。这套机制本身没问题，但换一台新机器（尤其没手动装过 Nerd Font 的机器）
时，mode-line/tab-line 里图标码位（分支图标、诊断图标、文件类型图标……）会渲染成豆腐块 □
——Windows 不自带任何打过 Nerd Font 补丁的字体，这是那次豆腐块 bug 的根因（见同一会话前半段
对 `lisp/init-bars.el` 的修复）。

把字体文件本身收进仓库，配一个一键装的脚本，能让"新机器 `git clone` 完，图标/中文/emoji
就是对的"这件事变成可复现的，不用每次都手动去找字体装。

## 版权调研：能 vendor 什么，不能 vendor 什么

本仓库是公开 GitHub 仓库（github.com/iysun/.emacs.d），只有明确允许"把字体文件本身重新
分发"的许可证才能塞进 `assets/`——"免费商用"跟"允许重新分发文件本体"是两回事，很多中文
字体厂商的授权协议只给前者，不给后者。

**调研过程中排查、确认不能 vendor 的**（仍然是 `init-ui.el` 候选表里的选项，本机装了就用，
只是不进仓库）：

- 微软雅黑 / DengXian / Segoe UI Symbol / Segoe UI Emoji ——Windows 自带的专有授权字体。
- 阿里巴巴普惠体——协议原文："未经阿里巴巴授权，任何人不得上传、发布、转载阿里巴巴字体
  文件"，明确禁止字体文件本身的重新分发。
- HarmonyOS Sans / Mi Sans——协议原文（HarmonyOS Sans 授权协议第 2 条）："HarmonyOS Sans
  字体及其任何单独组件都不得以独立形式重新分发或出售"；Mi Sans 条款几乎一致（用户猜测两者
  都出自汉仪的授权模板，两款字体都有汉仪参与制作）。

**能 vendor 的**（OFL-1.1 或同等自由许可，条款明确允许重新分发文件本身）：JetBrainsMono、
Sarasa Gothic 系列、Source Han Sans（思源黑体，Adobe+Google 联合发布）、Noto Color Emoji、
Symbola。这些字体的许可证文本本身就是为"随软件/仓库分发"设计的，思源黑体所在的 CJK
开源字体体系是国内外开源项目遇到"要不要塞进仓库"这类问题时的标准答案。

## 文件清单与来源

见 [`assets/fonts/README.md`](../../assets/fonts/README.md)——每个文件对应哪个上游仓库/
commit/tag/子路径，那边有表格，这里不重复。

## Windows 装字体的机制（为什么不能只把文件扔进 assets/ 就完事）

Emacs 在 Windows 上走 GDI/HarfBuzz 字体后端，没有 fontconfig 那种"直接指一个文件路径"的
机制——`find-font`/`font-family-list` 只认 Windows 自己知道的字体，文件本身放在哪都没用，
必须让 Windows"知道"这个字体存在。

`scripts/install-fonts.ps1` 做的事（Windows 10 1809+ 支持，全程不需要管理员，等价于把字体
文件拖进"设置 → 个性化 → 字体"）：

1. 复制到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts\`（当前用户级字体目录）。
2. 在 `HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Fonts` 下登记一条
   注册表项——这一步让字体在**下次登录/重启**时持久生效。
3. 当场对本次会话调用一次 `AddFontResourceEx`（P/Invoke `gdi32.dll`）——只写注册表不够：
   GDI 的会话级字体表不会因为注册表多了一条就自动重新扫描，得显式把字体资源加进当前会话，
   这样装完马上开一个新 Emacs 进程就能看到，不用重新登录。
4. 广播一次 `WM_FONTCHANGE`，让 Explorer 等长驻进程有机会刷新。

**Emacs 自己必须重启**才能看到新装的字体——它的字体表是进程启动时读一次的，不会热更新。

### 踩过的坑：文件名撞车

`assets/fonts/` 里的 JetBrainsMono 文件名特意保留了上游原名（含 `NL` 标记，即
`JetBrainsMonoNLNerdFontMono-Regular.ttf`），不能改短成
`JetBrainsMonoNerdFontMono-Regular.ttf`——本机实测过：这个"去掉 NL"的短名字，跟官方
nerd-fonts 安装器/官网下载包会用的 Ligatures 变体文件同名。如果两者都装在同一个每用户
字体目录下，后装的会把先装的**文件内容覆盖掉**，但注册表项各自独立、名字对得上、内容却
是另一个变体——`find-font` 认出来的字体就会驴唇不对马嘴。`install-fonts.ps1` 现在也加了
撞名保护：目标位置已有同名文件但内容（SHA256）对不上时，报错跳过、不覆盖。

### 字体实际的 family 名不一定是文件名或"看起来该叫什么"

vendor 前用 `System.Drawing.Text.PrivateFontCollection` 挨个实测了每个文件内部 name table
里真正的 family 名（PowerShell）：

```powershell
Add-Type -AssemblyName System.Drawing
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
Get-ChildItem assets\fonts -Include *.ttf,*.otf -Recurse | ForEach-Object { $pfc.AddFontFile($_.FullName) }
$pfc.Families | ForEach-Object { $_.Name }
```

结果里有两个反直觉的：

- Sarasa Term SC Nerd 这个补丁版构建的 family 名其实是**`更纱终端书呆黑体-简`**（中文），
  不是英文名 `Sarasa Term SC Nerd`（`init-ui.el` 候选表里原来那个英文名对应的是别的
  构建/版本，留着没坏处，但真正会命中的是中文名）。
- Source Han Sans SC 的 family 名是**`思源黑体`**（中文），不是 `Source Han Sans SC`。

`lisp/init-ui.el` 的候选表和 `scripts/install-fonts.ps1` 的清单都是按这次实测结果写的，
以后要是重新 vendor 别的版本/变体，记得重新跑一遍上面这段确认 family 名，不要靠猜。

## 重新 vendor（上游更新时）

1. 从对应上游仓库拉新文件（具体路径见 `assets/fonts/README.md`），替换掉
   `assets/fonts/` 下的同名文件；如果上游重新组织过目录结构，文件名可能变，参照
   README 表格重新核对。
2. 用上面那段 PowerShell 重新探测 family 名，跟 `lisp/init-ui.el` 候选表 /
   `scripts/install-fonts.ps1` 的 `$Manifest` 里写的对一下，不一致就同步改。
3. 跑一次 `scripts/install-fonts.ps1 -Force` 强制重装，重启 Emacs 确认字体生效。

## 调用

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-fonts.ps1
```

幂等：装过的会跳过。想强制重装（比如更新了 `assets/fonts/` 里的文件）加 `-Force`。
