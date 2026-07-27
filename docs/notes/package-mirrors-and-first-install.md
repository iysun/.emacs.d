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

## ⚠ Windows：MSYS 版 gpg 会让所有已签名包装不上

**现象**：`package-install` 任何 GNU ELPA 的签名包都报
`Failed to verify signature: "xxx.tar.sig"`，换镜像、换官方源、重建 keyring 都没用。

**根因**：PATH 上的 `gpg` 是 **Git for Windows 自带的 MSYS 版**
（`.../git/*/usr/bin/gpg.exe`）。Emacs 把 `package-gnupghome-dir` 以
`c:/Users/.../elpa/gnupg` 的形式传给它，MSYS 二进制**把带盘符的路径当成相对路径**，
拼出这么个东西：

```
/c/Users/Administrator/AppData/Roaming/.emacs.d/c:/Users/.../elpa/gnupg/pubring.kbx
```

于是永远找不到密钥环 → 一切签名校验失败。**包本身没问题**：同一个 tarball 用
`gpg --homedir ./elpa/gnupg --verify` （相对路径，MSYS 能正确解析）验证是
`Good signature`。

**判据**：在仓库根执行，能出 `Good signature` 就说明是路径问题而非密钥问题：

```sh
gpg --homedir ./elpa/gnupg --verify ./xxx.tar.sig ./xxx.tar
```

**根治**：装一个**原生 Windows** gpg 并让 Emacs 用它，例如
`scoop install gnupg`，然后在配置里 `(setq epg-gpg-program "<原生 gpg 路径>")`。
原生 gpg 能正确处理 `c:/...`。（本机当前只有 MSYS 版，尚未根治。）

**临时绕过**：确认签名无误后，只对该次安装关校验：

```elisp
(let ((package-check-signature nil)) (package-install 'some-package))
```

> 顺带一提：`early-init.el` 那段「无 keyring 时关校验」的兜底在这里**不会**触发——
> keyring 文件是存在的，只是 gpg 找不到它。

## 排查"缺包"报错

`Cannot open load file: xxx` 多半是首次安装没跑完。让用户在**交互** Emacs 里触发安装
（启动时 `use-package :ensure t` 会自动装），装完再验证。批处理环境不适合跑首次联网安装。
