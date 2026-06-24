;; init.el    -*- lexical-binding: t -*-

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; ---- Profile dispatch: 精简(minimal) vs 全量(full) ----
;; 命中 `--minimal' 命令行参数 或 `EMACS_MINIMAL' 环境变量 即走精简；默认全量。
;; `--minimal' 不是 Emacs 内置参数，需在此处（早于 `command-line-1' 处理剩余参数）
;; 从 `command-line-args' 中删除，否则启动末尾会报 "Unknown option"。
(defvar my/emacs-minimal-p
  (let ((flag (member "--minimal" command-line-args)))
    (when flag
      (setq command-line-args (delete "--minimal" command-line-args)))
    (or flag (getenv "EMACS_MINIMAL")))
  "Non-nil 表示以精简 profile 启动。")

(setq custom-file "~/.emacs.d/custom.el")
(when (file-exists-p custom-file)
  (load custom-file))

(if my/emacs-minimal-p
    ;; ===== 精简 profile：只加载精简配置 =====
    ;; init-minimal.el 与本文件同级（非 lisp/），故按路径 load，不走 load-path。
    (progn
      (message "Emacs 精简模式启动 (minimal profile)")
      (load (expand-file-name "init-minimal" user-emacs-directory)))

  ;; ===== 全量 profile：模块化配置 =====
  (require 'package)
  (setq package-archives
        '(("gnu"    . "https://mirrors.ustc.edu.cn/elpa/gnu/")
          ("melpa"  . "https://mirrors.ustc.edu.cn/elpa/melpa/")
	  ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")
          ("org"    . "https://mirrors.ustc.edu.cn/elpa/org/")))
  ;;(setq package-archive
  ;;  '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
  ;;    ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
  ;;  ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
  (package-initialize)

  (require 'use-package)

  (dolist (package
           '(evil
             evil-collection
             evil-surround
             evil-visualstar
             evil-commentary
             posframe
             multiple-cursors
             treesit-auto
             ace-window
             hydra
             exec-path-from-shell
             nerd-icons
             nerd-icons-completion
             nerd-icons-corfu
             nerd-icons-dired
             rainbow-delimiters
             doom-themes
             doom-modeline
             centaur-tabs
             popper
             consult
             embark
             embark-consult
             marginalia
             consult-eglot
             eldoc-mouse
             dashboard
             magit
             diff-hl
             dired-quick-sort
             dired-git-info
             dired-rsync
             diredfl
             dired-subtree
             eshell-git-prompt
             eshell-syntax-highlighting
             capf-autosuggest
             orderless
             vertico
             corfu
             corfu-terminal
             cape
             eat))
    (eval `(use-package ,package :ensure t :defer t)))

  (when (executable-find "fd")
    (use-package fd-dired :ensure t :defer t)
    (require 'fd-dired))

  (require 'init-base)
  (require 'init-evil)
  (require 'init-ui)
  (require 'init-window)
  (require 'init-completion)
  (require 'init-dired)
  (require 'init-git)
  (require 'init-term)
  (require 'init-project)
  (require 'init-mc)

  (require 'init-keymaps)
  (require 'init-lsp)

  ;;(require 'init-ai)
  ;;(require 'init-evil-plugins)
  ;;
  ;;(require 'lang-go)
  )
