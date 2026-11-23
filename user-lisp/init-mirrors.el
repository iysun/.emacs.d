;; init-mirrors.el 	-*- lexical-binding: t -*-

(require 'package)

(defconst my/package-archives-ustc
  '(("gnu"    . "https://mirrors.ustc.edu.cn/elpa/gnu/")
    ("melpa"  . "https://mirrors.ustc.edu.cn/elpa/melpa/")
    ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")
    ("org"    . "https://orgmode.org/elpa/"))
  "中科大（USTC）镜像，当前唯一使用的源。")

(setq package-archives my/package-archives-ustc)

(provide 'init-mirrors)
