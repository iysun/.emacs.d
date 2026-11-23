# eshell-syntax-highlighting（vendored + patched）

- 上游：<https://github.com/akreisher/eshell-syntax-highlighting>
- 版本：`20241222.2030`（commit `62418fd8b238`）
- 许可：GPL-3.0-or-later（原文件版权头保留）

## 为什么 vendor

这个包在 `post-command-hook` 里每次重新高亮都会对当前命令调 `executable-find`；
命令没敲完时必然 miss。Windows 上一次 miss 约 2–3ms，打字时会有可感卡顿。
原配置用一个全局 `executable-find` advice 缓存，范围偏大、也不随 `exec-path` 失效。
把它 vendor 进来后缓存只存在于高亮器内部，配置侧不再需要任何 advice。

## 本地补丁

只改了 `eshell-syntax-highlighting--executable-find` 宏及紧邻的缓存设施：

- 新增 `eshell-syntax-highlighting--executable-cache`。
- 新增交互命令 `eshell-syntax-highlighting-clear-executable-cache`。
- 缓存键：`(命令 exec-path exec-suffixes remote-dir)`；带 `exec-path`/`exec-suffixes`
  意味着 PATH 变化后旧条目自动不再命中。
- 缓存值：可执行文件路径或 `nil`（负缓存）。

`init-term.el` 里保留一个 `my/eshell-clear-executable-cache` 包装命令，方便 `M-x` 找。

## 升级

上游升级时重新取 `eshell-syntax-highlighting.el`，把上述补丁重新应用到
`eshell-syntax-highlighting--executable-find` 附近；不要装 ELPA 版，否则会和本目录重名。
