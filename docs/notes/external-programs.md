# 本机第三方程序

Emacs 会调用 PATH（少数看固定路径）上的一批外部程序。缺了往往**静默降级**（功能不加载、eglot 换回退、命令报找不到），启动时**不会**检查。

权威清单在 `user-lisp/init-externals.el` 的 `iys/external-programs`。换机器或怀疑 PATH：

```
M-x iys/check-external-programs
```

`C-u` 只列出缺失项。改清单时这个文件和 Elisp 一起改。

## 核心

| 程序 | 用途 |
|------|------|
| `git` | VC、eshell 提示符、`consult-git-grep` |

## 功能（没有就关一项）

| 程序 | 用途 | 没有会怎样 |
|------|------|------------|
| `rg` | xref 搜索、`consult-ripgrep`（`M-s r`） | xref 不走 ripgrep |
| `fd` | `consult-fd`（`M-s f`）、fd-dired | 不装 fd-dired；文件查找弱一档。Debian 二进制常叫 `fdfind`，PATH 上要有名为 `fd` 的入口 |
| `locate` | `consult-locate`（`M-s c`） | 该命令不可用 |
| `ctags` | Universal Ctags；lspmux 建/增量符号索引 | mux 的 tags 源没有索引（不写仓库 `tags` 文件） |
| `shfmt` | apheleia 格式化 `sh-mode` | 不把 sh 交给 shfmt |
| `node` | npm 语言服务器的运行时 | html/css/ts/pyright 起不来 |
| `cc` | `treesit-install-language-grammar` | 装 grammar 失败 |
| `fcitx5-remote` | Linux/macOS：退出插入态切英文；`C-SPC` 开输入法 | 不切输入法 |
| `im-select.exe` | Windows：同上，路径 `iys/im-select-path` | 不切输入法 |
| `pwsh` | Windows：ghostel 默认 shell | ghostel 起不来或落到别的壳 |
| `xdg-open` | Linux：dired 打开 pdf/图片/视频 | 猜测的打开命令为空 |

## 语言服务器（按你编辑的语言）

| 程序 | 语言 |
|------|------|
| `lspmux` | eglot 唯一入口；按 languageId 拉起下面的上游 |
| `vscode-html-language-server` | HTML（lspmux 上游） |
| `vscode-css-language-server` | CSS，以及 HTML 里的 `<style>` |
| `typescript-language-server` | JS/TS/TSX，以及 HTML 里的 `<script>` |
| `clangd` | C/C++ |
| `pyright-langserver` | Python |
| `gopls` | Go |
| `rust-analyzer` | Rust |

eglot 只连 `lspmux`。打开某种语言时 mux 才拉对应上游；上游仍要在 PATH 上（mux 按 argv 拉子进程，不负责安装）。

`lspmux` 源码钉在本仓 `vendor/lspmux`（submodule）。装二进制：

```
cargo install --path ~/.emacs.d/vendor/lspmux --bin lspmux
```

日常开发仍在 `~/work/projects/lspmux`；推送后再更新 submodule SHA 并重装。

## 不在这份 PATH 清单里的

- ELPA 包（`init.el` 的 `iys/packages`）
- ghostel 的原生模块（`var/ghostel/`，Windows 还有 ConPTY）
- tree-sitter grammar 本身（用 `cc` + git 现编）
- 字体（dotfiles）
