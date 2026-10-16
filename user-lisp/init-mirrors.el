;; init-mirrors.el 	-*- lexical-binding: t -*-

(require 'package)

(defconst my/package-archives-ustc
  '(("gnu"    . "https://mirrors.ustc.edu.cn/elpa/gnu/")
    ("melpa"  . "https://mirrors.ustc.edu.cn/elpa/melpa/")
    ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")
    ("org"    . "https://mirrors.ustc.edu.cn/elpa/org/"))
  "中科大（USTC）镜像。当前使用。")

(defconst my/package-archives-tuna
  '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
    ("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
    ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
    ("org"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/org/"))
  "清华 TUNA 镜像。备选：把下面 `setq' 改成引用本变量即可。")

(defconst my/package-archives-official
  '(("gnu"    . "https://elpa.gnu.org/packages/")
    ("melpa"  . "https://melpa.org/packages/")
    ("nongnu" . "https://elpa.nongnu.org/nongnu/")
    ("org"    . "https://orgmode.org/elpa/"))
  "官方源。走代理或在境外机器时可用。")

(setq package-archives my/package-archives-ustc)

(provide 'init-mirrors)
