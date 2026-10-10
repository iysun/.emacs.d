# evil-plugins

evil 相关的插件合集。第三方包已**内联（vendored）**进本目录，不再从 elpa 安装；
由 Emacs 31 的 user-lisp 机制自动加入 load-path、按需字节编译、抓 autoload。

| 文件 | 来源 | 说明 |
|------|------|------|
| `evil-surround.el` | MELPA `evil-surround`（2024-03-25） | `cs`/`ds`/`ys` 等 |
| `evil-commentary.el` + `evil-commentary-integration.el` | MELPA `evil-commentary`（2023-06-10） | `gcc` 注释 |
| `evil-visualstar.el` | MELPA `evil-visualstar`（2016-02-23） | `*`/`#` 选中后继续搜 |
| `evil-config.el` | 本仓库（原 `init-evil.el`） | `evil-want-*`、`evil-mode`、text object、装载上面三个 |
| `evil-keymaps.el` | 本仓库（原 `init-keymaps.el` 的 evil 部分） | evil 专属键位 |
| `evil-vc.el` | 本仓库，自 evil-collection（20260623.308）提取 | vc-dir / vc-annotate / log-view / log-edit / diff-mode 的 evil 键位 |
| `evil-dired.el` | 本仓库，自 evil-collection（20260623.308）提取 | dired 的 evil 键位 |
| `evil-ibuffer.el` | 本仓库，自 evil-collection（20260623.308）提取 | ibuffer 的 evil 键位 |
| `evil-extra.el` | 本仓库，自 evil-collection（20260623.308）提取 | 其它 special mode 的 evil 键位：compile / embark / help / xref / package-menu / grep / wgrep / proced |
| `evil-textobjects.el` | 本仓库（原 `init-evil-plugins.el`，**停用**） | text object（与 `evil-config.el` 有重复） |
| `mc-evil.el` | 本仓库（原 `init-mc.el`） | multiple-cursors 与 evil 联动 |
| `ime.el` | 本仓库（原 `init-ime.el`） | 输入法切换（由 `early-init.el` 绝对路径 `load`） |

第三方文件均为 **GPLv3**（见各文件头）。本地个人使用；若公开分发需注意 GPL 传染。
内联的包不再自动跟进上游更新，升级需手动替换对应文件。
