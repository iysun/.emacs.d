# 用 portable dump（emacs.pdmp）加速启动

把启动期/常用重包预加载进一个 dump 映像，启动时 `--dump-file` 内存映射回来，省掉 `require` 的几秒。
**实测 GUI `emacs-init-time` ~5.6s → ~3.3s。** 脚本 `dump.el`，构建 `make dump`（= `/build`）。

## 启动方式
```powershell
emacs --dump-file=<.emacs.d>\emacs.pdmp     # 或把快捷方式指向 emacs-dump.cmd
```
`emacs-dump.cmd`：存在 `emacs.pdmp` 就带 `--dump-file` 启动，否则回退普通启动。

## 原理
自定义 dump 是标准 dump 的**超集**：从（标准 dump 起来的）emacs 里 `require` 重包，再
`dump-emacs-portable` 写出新映像。启动时 early-init/init 照常运行，`(require 'evil)` 等命中映像即瞬返。
**只预加载第三方库，不在 dump 期跑用户 init**——dump 期无显示，跑 init 会踩字体/frame/主题坑。

预加载集（见 `dump.el` 的 `my/dump-packages`，当前 20 个）：evil 全家桶、补全栈（vertico/corfu/
consult/embark/embark-consult/marginalia/orderless/cape）、doom-themes、hydra、project（核心）
+ eglot/magit/popper/ace-window（加分；若转储报错优先从加分组删）。`eat` 因含 C 扩展已排除。

构建时留意这两行输出，能一眼看出是不是又踩了下面的静默 bug：
```
dump: 已激活 65/65 个包        ← 分子远小于分母 = 包激活出问题（见「两个静默 bug」①）
dump: 预加载 20 个包，跳过 0 个 ← 跳过不为 0 = 映像残缺
```

## 踩过的三个坑（都已在 dump.el 处理）
1. **`dumping overlays is not yet implemented`**：某包加载时建了 overlay，pdumper 不支持。
   → 转储前 `remove-overlays` 清掉所有缓冲区的 overlay（纯显示态，运行时按需重建）。
2. **没烤进映像的包找不到（如 `fd-dired`）→ init.el 中途报错**：`dump-emacs-portable` 丢掉了
   load-path 的运行期追加，却保留 `package-activated-list`，于是启动时 `package-initialize` 见「已激活」
   就跳过、不再把目录加回 load-path。→ 转储前复位 `package--initialized` / `package-activated-list` /
   `package-alist`，让启动时 `package-initialize` 从头重建 load-path（已烤进的包代码仍在内存，require 照样瞬返）。
3. **evil-collection #60 警告**：dump 把 evil 以默认 `evil-want-keybinding` 烤进去，启动时再设已太晚。
   → dump.el 在 `(require 'evil)` 前先设 `evil-want-keybinding nil`（及其余 evil-want-*，与 init-evil.el 一致）。

> 排错提醒：用映像启动若 `emacs-init-time` **小得异常**（如 0.4s），多半是 init.el **中途崩了**没跑完
> （模块没加载），不是真快——去看 `*Warnings*`。

### 又一个 dump 特有坑：region 不 active（多光标 visual 模式）
现象：dump 启动时，evil visual 选中后按 `C-M-n`（multiple-cursors）报 `end-of-buffer`；普通启动正常。
根因：`init-mc.el` 的 advice 退出 visual 后 `(set-mark)` 设了选区，但 **dump 下 `transient-mark-mode`
状态不同，仅 set-mark 不足以让 `(region-active-p)` 为真**；mc 见「无选区」便去标下一行 → 撞 buffer 末尾。
修复：advice 里 `(set-mark)` 后再 `(setq deactivate-mark nil) (activate-mark)` 强制激活选区。
教训：**dump 会改变一些全局/默认变量的初值（如 transient-mark-mode）**，依赖这些默认值的代码要显式置态。

## Windows 已知问题与 runemacs.exe

### Emacs 31.0.90 预发布版：`--dump-file` 必然崩溃（暂停使用 pdmp）
**现象**：`runemacs.exe --dump-file=emacs.pdmp` 静默退出（exit 0），`emacs.exe --dump-file=emacs.pdmp`
报 `Error using execdir D:\emacs31\bin\: 找不到指定的模块`，Windows 事件日志 `0xC0000005`
（STATUS_ACCESS_VIOLATION）在 `emacs.exe` 自身偏移 `0x17ad35`。
**根因**：Emacs 31.0.90 预发布版在 Windows 上加载任意 `--dump-file` 时触发二进制级 bug，与
dump 内容无关（空 dump 也崩）。
**处置**：开始菜单快捷方式改为直接用 `runemacs.exe`（无 `--dump-file`），等 Emacs 31 正式版修复后
再 `make dump` 重建并恢复快捷方式参数。
> ⚠ 下面「两个静默 bug ②」会产生**一模一样**的症状（静默 exit 0 / `0xC0000005`），但那个是
> 内容相关、可修的。判断哪一种，用那节末尾的**空 dump 判据**，别直接按本节结论放弃 pdmp。
> Emacs 30.2（scoop）实测：空 dump 正常 → 属于 ②，修完 pdmp 已恢复可用。

### dump.el 已加的两个 Windows 防御性配置
1. `(setq native-comp-eln-load-path nil)`（dump 构建期）：让包回退字节编译版本，避免 dump 里烤入
   `.eln`（native-comp DLL）路径引用——加载 dump 时 `LoadLibrary` 调用时序早于 PATH 完全建立，
   会导致"找不到指定的模块"。
   ⚠ **现已改为「仅当本 Emacs 真支持 native-comp 时才清」**，见下面「清空 eln 路径反而把映像弄崩」。
2. `eat` 从预加载集中排除：`eat` 含 C 扩展（`eat-core.dll`），烤进 dump 后恢复时有额外崩溃风险。

## 两个静默 bug（2026-07-27 排查，均已修）

### ① 构建期只烤进了 9/20 个包（静默）
**现象**：`make dump` 报 `dump: 跳过 vertico/consult/corfu/magit/...`（11 个 file-missing），
但这些包在 `elpa/` 下明明装着；转储照样"成功"，产出一个残缺映像。
**根因**：Emacs 启动阶段（早于 `-l dump.el`）已按**默认** `user-emacs-directory` 跑过一轮
`package-activate-all`。从 **Git Bash / make 里跑时 `HOME` 被设成 `C:\Users\<user>`**，
`~/.emacs.d` 于是不再是本仓库（本仓库在 `%APPDATA%\.emacs.d`），
那边残留的**过期 `package-quickstart.el`** 被当成激活清单读进来 → 只激活到 11/65 个包。
**修复**：`dump.el` 在 `package-initialize` 前把 `package-quickstart-file` 指回本仓库
（那里没有该文件 → 走真正的目录扫描），并清空 `package--initialized` /`package--activated` /
`package-alist` / `package-activated-list`，强制按本仓库 `elpa/` 重新激活。
现在构建会打印 `dump: 已激活 65/65 个包`，可据此一眼确认。

### ② 清空 eln 路径反而把映像弄崩（0xC0000005）
**现象**：映像能转储成功，但 `--dump-file` 启动**静默退出**（exit 0，什么都不执行）或直接段错误
（`0xC0000005`）。和上面那条 Emacs 31 的症状长得一模一样，极易误判成同一个问题。
**根因**：`(setq native-comp-eln-load-path nil)` 在**不支持 native-comp** 的构建上（如 scoop 的
Emacs 30.2）没有任何防御价值（根本不存在 `.eln`），却会让转出的映像加载时崩溃。
且需要「激活/加载的包足够多」才触发——所以 bug ① 只烤 9 个包时看不出来，两个 bug 互相掩护。
**对照实验**（同一台机器，其余条件相同）：

| 组合 | 结果 |
|------|------|
| 空 dump（不碰 package） | ✅ 正常启动 |
| 65 包激活 + **不清** eln 路径 | ✅ 正常启动 |
| 65 包激活 + **清空** eln 路径 | ❌ 段错误 0xC0000005 |
| 11 包激活 + 清空 eln 路径 | ✅ 正常启动（包不够多，没触发） |

**修复**：加 `native-comp-available-p` 守卫，只在真有 native-comp 时才清空。
native-comp 可用的机器上原防御照旧生效。

> 判据：先转一个**空 dump**（`emacs --batch -Q --eval '(dump-emacs-portable "/tmp/e.pdmp")'`）
> 试启动。空 dump 能起 → 是**内容相关**的问题（往这两条查）；空 dump 也崩 → 才是
> Emacs 31 那种二进制级 bug。

### 开始菜单快捷方式：用 runemacs.exe，不用 emacs.exe
- `emacs.exe`：控制台子系统，启动时**必然弹一个额外终端窗口**。
- `runemacs.exe`：Windows GUI 子系统，启动**无终端窗口**。
- 快捷方式应始终指向 `runemacs.exe`（`D:\emacs31\bin\runemacs.exe`）。

## 维护成本（pdmp 与 emacs 二进制强绑定）
- **装/删包后** → `make dump` 重建。
- **`scoop update emacs` 后** → 二进制 hash 变，旧 pdmp 不兼容、启动报错 → `make dump` 重建。
- 启动器对「pdmp 缺失」会回退普通启动；对「不兼容」仍会报错——见到就重建。

## 和 daemon 的取舍
dump 把加载时间压到 ~3.3s（真实建帧/重绘那部分省不掉）。想"秒开"且省心仍是 **daemon + emacsclient**
（一次常驻、之后窗口瞬开、无需随包/版本重建）。dump 适合"不想用 daemon、又要压加载时间"。
