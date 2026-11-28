# LSP Servers

Eglot 使用的 LSP server 汇总。配置入口：`user-lisp/init-lsp.el`。
eglot **只连** `lspmux`；下面各语言服务器是 mux 按 languageId 拉起的上游，仍要在 PATH 上。

## lspmux（唯一入口）

- **源码**：本仓 submodule `vendor/lspmux`（`iysun/lspmux`）
- **安装**：`cargo install --path vendor/lspmux --bin lspmux`
- **验证**：`lspmux --help`
- **更新**：lspmux `main` 推送后 `git submodule update --remote vendor/lspmux`，再 `--force` 重装
- **触发**：`init-lsp.el` 里所有托管 mode

## Go — gopls

- **安装**：`go install golang.org/x/tools/gopls@latest`
- **验证**：`gopls version`
- **触发 mode**：`go-ts-mode`

gopls 安装到 `$GOPATH/bin`（默认 `~/go/bin`），确保该目录在 `PATH` 中。

## Python — pyright

- **安装**：`pip install pyright`
- **升级**：`pip install -U pyright`
- **验证**：`pyright-langserver --version`
- **触发 mode**：`python-ts-mode`, `python-mode`

## JS / TS — typescript-language-server

- **安装**：`npm install -g typescript-language-server typescript`
- **升级**：`npm update -g typescript-language-server typescript`
- **验证**：`typescript-language-server --version`
- **触发 mode**：`js-ts-mode`, `typescript-ts-mode`, `tsx-ts-mode`

## C / C++ — clangd

- **安装**：随 LLVM 安装
  - Windows：`winget install LLVM.LLVM` 或 `scoop install llvm`
  - macOS：`brew install llvm`
  - Linux：`apt install clangd` / `dnf install clang-tools-extra`
- **验证**：`clangd --version`
- **触发 mode**：`c-ts-mode`, `c++-ts-mode`

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
