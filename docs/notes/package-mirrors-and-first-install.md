# 包镜像与新机器首次安装

## 镜像

包源用 USTC 镜像（`init.el` 全量分支与 `init-minimal.el` 各有一份 `package-archives`）。
清华 TUNA 的备选在 `init.el` 里注释保留。**换镜像时两处都要改。**

## 新机器首次安装的签名校验兜底

新机器本地还没有 GnuPG keyring 时，GNU ELPA 已签名包（compat / eglot 等）会因
"No public key" 安装失败，并连累依赖它们的 consult/vertico/corfu/magit 等。

`early-init.el` 的处理：**仅当**本地没有 `elpa/gnupg/pubring.kbx` 时关闭 `package-check-signature`；
一旦机器有了 keyring（如已导入 GNU ELPA 公钥）仍按默认校验。

## 排查"缺包"报错

`Cannot open load file: xxx` 多半是首次安装没跑完。让用户在**交互** Emacs 里触发安装
（启动时 `use-package :ensure t` 会自动装），装完再验证。批处理环境不适合跑首次联网安装。
