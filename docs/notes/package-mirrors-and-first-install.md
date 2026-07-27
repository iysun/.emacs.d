# 包镜像与新机器首次安装

## 镜像

包源集中在 **`lisp/init-mirrors.el`**（唯一定义处），USTC / 清华 TUNA / 官方三套各存一个常量，
文件末尾一行 `setq` 选用哪套。**换镜像只改那一行。**

三条加载路径都从这里取，不要再在别处写 `package-archives`：

| 使用方 | 取法 |
|--------|------|
| `init-full.el` | `(require 'init-mirrors)` |
| `init-minimal.el` | `(require 'init-mirrors)` |
| `dump.el` | 同上（`-Q` 起，故先把 `lisp/` 加进 `load-path`） |

> 历史：这三处原本各抄一份，`dump.el` 那份还漏在了 AGENTS.md 的「改镜像要改两处」之外。

## 新机器首次安装的签名校验兜底

新机器本地还没有 GnuPG keyring 时，GNU ELPA 已签名包（compat / eglot 等）会因
"No public key" 安装失败，并连累依赖它们的 consult/vertico/corfu/magit 等。

`early-init.el` 的处理：**仅当**本地没有 `elpa/gnupg/pubring.kbx` 时关闭 `package-check-signature`；
一旦机器有了 keyring（如已导入 GNU ELPA 公钥）仍按默认校验。

## 排查"缺包"报错

`Cannot open load file: xxx` 多半是首次安装没跑完。让用户在**交互** Emacs 里触发安装
（启动时 `use-package :ensure t` 会自动装），装完再验证。批处理环境不适合跑首次联网安装。
