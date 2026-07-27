;; init-mirrors.el 	-*- lexical-binding: t -*-
;;
;; 包源镜像的**单一定义处**。全量 / 精简 / dump 三条路径都从这里取，
;; 切镜像只改本文件一处。
;;
;; 使用方（都在 `package-initialize' 之前）：
;;   init-full.el     (require 'init-mirrors)
;;   init-minimal.el  (require 'init-mirrors)
;;   dump.el          按路径 load（-Q 起，load-path 里没有 lisp/）
;;
;; 注意：本文件只设 `package-archives'，不调用 `package-initialize'，
;; 由各使用方自行决定初始化时机。

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

;; ↓↓↓ 换镜像只改这一行 ↓↓↓
(setq package-archives my/package-archives-ustc)

(provide 'init-mirrors)
