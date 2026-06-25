# LSP Servers

Eglot 使用的 LSP server 汇总。配置入口：`lisp/init-lsp.el`。

## Go — gopls

| 项 | 值 |
|---|---|
| 安装路径 | `C:\Users\Administrator\go\bin\gopls.exe` |
| 安装命令 | `go install golang.org/x/tools/gopls@latest` |
| 触发 mode | `go-ts-mode` |

## Python — pyright

| 项 | 值 |
|---|---|
| 安装路径 | `D:\Applications\Scoop\apps\python\current\Scripts\pyright-langserver.exe` |
| 安装命令 | `pip install pyright` |
| 升级命令 | `pip install -U pyright` |
| 触发 mode | `python-ts-mode`, `python-mode` |

## JS / TS — typescript-language-server

| 项 | 值 |
|---|---|
| 安装路径 | `D:\Working_Tools\nodejs\node_global\typescript-language-server.ps1` |
| 安装命令 | `npm install -g typescript-language-server typescript` |
| 升级命令 | `npm update -g typescript-language-server typescript` |
| 触发 mode | `js-ts-mode`, `typescript-ts-mode`, `tsx-ts-mode` |

## C / C++ — clangd

| 项 | 值 |
|---|---|
| 安装命令 | 随 LLVM 安装：`winget install LLVM.LLVM` 或 scoop `scoop install llvm` |
| 触发 mode | `c-ts-mode`, `c++-ts-mode` |

## 常用 Eglot 命令

| 命令 | 说明 |
|---|---|
| `M-x eglot` | 手动启动 LSP |
| `M-x eglot-shutdown` | 关闭当前 LSP |
| `M-x eglot-reconnect` | 重连 LSP |
| `M-x consult-eglot-symbols` | 搜索工程符号 |
| `M-.` | 跳转定义 |
| `M-,` | 跳回 |
| `M-?` | 查找引用 |
