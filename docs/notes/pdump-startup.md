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

预加载集（见 `dump.el` 的 `my/dump-packages`）：evil 全家桶、补全栈（vertico/corfu/consult/embark/
marginalia/orderless/cape）、doom-themes、hydra、project（核心）+ nerd-icons/eglot/treesit-auto/
magit/popper/ace-window/eat（加分；若转储报错优先从加分组删）。

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

## 维护成本（pdmp 与 emacs 二进制强绑定）
- **装/删包后** → `make dump` 重建。
- **`scoop update emacs` 后** → 二进制 hash 变，旧 pdmp 不兼容、启动报错 → `make dump` 重建。
- 启动器对「pdmp 缺失」会回退普通启动；对「不兼容」仍会报错——见到就重建。

## 和 daemon 的取舍
dump 把加载时间压到 ~3.3s（真实建帧/重绘那部分省不掉）。想"秒开"且省心仍是 **daemon + emacsclient**
（一次常驻、之后窗口瞬开、无需随包/版本重建）。dump 适合"不想用 daemon、又要压加载时间"。
