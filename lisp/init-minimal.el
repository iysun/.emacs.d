;;; init-minimal.el --- 精简启动配置 -*- lexical-binding: t; -*-
;;
;; 单文件轻量配置：evil + 内置 project/eglot + completion-preview。
;; 由仓库根 `init.el' 在 `--minimal' / `EMACS_MINIMAL' 命中时加载。
;; GC 延迟与 custom-file 由 `early-init.el' / 根 `init.el' 统一处理，此处不再重复。

(progn
  (when (member "JetBrainsMono NFM" (font-family-list))
    (set-frame-font "JetBrainsMono NFM"))
  (when (member "微软雅黑" (font-family-list))
    (set-fontset-font t 'han (font-spec :family "微软雅黑" :size 16)))

  ;; (set-default default-directory "~/")
  ;; (set-frame-font "FiraCode Nerd Font")
  (electric-pair-mode t)
  (setq display-line-numbers-type 'relative)
  (global-display-line-numbers-mode t)

  (set-language-environment 'utf-8)
  (set-default-coding-systems 'utf-8)
  (prefer-coding-system 'utf-8)

  (menu-bar-mode -1)
  (scroll-bar-mode -1)
  (tool-bar-mode -1)

  (setq inhibit-startup-screen t)
  (savehist-mode 1)
  (global-auto-revert-mode t) ;; 其他文件更新时更新文件
  (setq make-backup-files nil) ;; 关闭备份文件


  (setq completion-ignore-case t) ;; 补全忽略大小写
  (setq project-vc-extra-root-markers '(".project"))
  )

(require 'package)
(setq package-quickstart t)
(setq package-archives '(("gnu" . "https://mirrors.ustc.edu.cn/elpa/gnu/")
			 ("melpa" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
			 ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")))
(package-initialize)

(dolist (package
         '(evil
           evil-collection
           multiple-cursors
           ;; corfu
           doom-themes))
  (eval `(use-package ,package :ensure t :defer t)))

(progn
  (setq doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (setq doom-themes-enable-italic t) ; if nil, italics is universally disabled
  (load-theme 'doom-ayu-light t)
  )

;; VSCode-like split layout, based on Emacs default mode-line segments.

(setq-default mode-line-format
              '("%e"
                mode-line-front-space
                (:eval
                 (if (bound-and-true-p evil-local-mode)
                     (format "%s " evil-mode-line-tag)
                   ""))
                mode-line-buffer-identification
                mode-line-format-right-align
                (:eval
                 (when (and (bound-and-true-p flymake-mode)
                            (boundp 'flymake-mode-line-format))
                   (format-mode-line flymake-mode-line-format)))
                " "
                (:eval (when vc-mode (format-mode-line '(vc-mode vc-mode))))
                " "
                mode-line-misc-info
                " "
                mode-line-front-space
                mode-line-end-spaces))

(set-face-attribute 'mode-line nil :box nil :height 110)
(set-face-attribute 'mode-line-inactive nil :box nil :height 110)

(add-hook 'after-init-hook 'fido-vertical-mode)

(progn
  (setq evil-want-integration t)		; 与 Emacs minor modes 集成
  (setq evil-want-keybinding nil)
  (setq evil-shift-width 2)
  (setq evil-search-module 'evil-search)	; 必须！支持 gn / cgn
  (setq evil-respect-visual-line-mode t)	; 在 visual-line-mode 中按行移动
  (setq evil-cross-lines t)			; j/k 可跨软换行行（类似 Vim）
  (setq evil-undo-system 'undo-redo)		; 使用 Emacs 的 undo-tree 或简易 undo-redo
  )

;; (progn
;;   (setq corfu-auto t)
;;   (global-corfu-mode)
;;   (corfu-popupinfo-mode)
;;   )

(add-hook 'prog-mode-hook 'eglot-ensure)
(add-hook 'go-mode-hook 'eglot-ensure)

;; (add-hook 'window-setup-hook #'toggle-frame-maximized)

(defun my/tab-line-buffer-group-by-project (&optional buffer)
  "Group buffers by project root via project.el."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((dir (or (buffer-file-name) nil))
           (proj (project-current nil dir))
           (root (when proj (project-root proj))))
      (if (and root dir)
          (file-name-nondirectory (directory-file-name root))
	"Other"))))

(defun my/tab-line-filter (buffers)
  "Filter out Eglot-generated buffers from tab-line."
  (let (result)
    (dolist (buf buffers (nreverse result))
      (let ((name (buffer-name buf)))
        (unless (and name
                     (let ((case-fold-search t))
		       (string-match-p "\\`\\s-*\\*eglot" name)))
          (push buf result))))))
(progn
  (setq tab-line-tabs-function 'tab-line-tabs-buffer-groups)
  (setq tab-line-tabs-buffer-group-function #'my/tab-line-buffer-group-by-project)
  (advice-add 'tab-line-tabs-buffer-list :filter-return #'my/tab-line-filter)
  )

(add-hook 'after-init-hook 'global-tab-line-mode)
(add-hook 'after-init-hook 'evil-mode)
(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer 0.2 nil #'evil-collection-init)))


(defvar my/is-multiple-cursors-mode nil)

;; 自动在 multiple-cursors 模式下禁用 evil，退出后重新启用
(defun my/disable-evil-for-mc (&rest _args)
  "在 multiple-cursors 模式启用时，局部禁用 evil。"
  (when (not my/is-multiple-cursors-mode)
    (cond
     ((evil-visual-state-p)
      (let ((mrk (mark))
	    (pnt (point)))
	(evil-emacs-state)
	(set-mark mrk)
	(goto-char pnt)))
     (t
      (evil-emacs-state)))
    (setq-local my/evil-was-active-before-mc t)
    (setq my/is-multiple-cursors-mode t)
    )
  )

(defun my/restore-evil-after-mc (&rest _args)
  "在 multiple-cursors 模式禁用时，恢复之前 evil 的状态。"
  (when (and (boundp 'my/evil-was-active-before-mc)
	     my/evil-was-active-before-mc)
    (evil-normal-state)
    (setq my/is-multiple-cursors-mode nil)
    (kill-local-variable 'my/evil-was-active-before-mc))) ; 清理变量

;; 添加钩子
;; (add-hook 'multiple-cursors-mode-enabled-hook #'my/disable-evil-for-mc)
(dolist (cmd '(mc/mark-next-like-this
	       mc/mark-previous-like-this
	       mc/mark-all-like-this
	       mc/mark-all-like-this-dwim
	       mc/mark-next-like-this-word
	       mc/mark-previous-like-this-word
	       mc/mark-next-symbol-like-this
	       mc/mark-previous-symbol-like-this
	       mc/mark-all-in-region
	       mc/edit-lines
	       mc/insert-numbers))
  (advice-add cmd :before #'my/disable-evil-for-mc))
(add-hook 'multiple-cursors-mode-disabled-hook #'my/restore-evil-after-mc)

(global-set-key (kbd "C-M-p") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-M-n") 'mc/mark-next-like-this)
(global-set-key (kbd "M-<down>") 'mc/mark-next-like-this-word)

(add-hook 'prog-mode-hook #'completion-preview-mode)
(add-hook 'text-mode-hook #'completion-preview-mode)
(with-eval-after-load 'comint
  (add-hook 'comint-mode-hook #'completion-preview-mode))
(with-eval-after-load 'completion-preview
  (setq completion-preview-minimum-symbol-length 1)
  (push 'org-self-insert-command completion-preview-commands)
  (push 'paredit-backward-delete completion-preview-commands)
  (keymap-set completion-preview-active-mode-map "M-n" #'completion-preview-next-candidate)
  (keymap-set completion-preview-active-mode-map "M-p" #'completion-preview-prev-candidate))

;; Convenient alternative to C-i after typing one of the above
(global-set-key (kbd "M-j") 'completion-at-point)
(with-eval-after-load 'evil
  (define-key evil-insert-state-map (kbd "C-a") 'move-beginning-of-line)
  (define-key evil-insert-state-map (kbd "C-e") 'move-end-of-line)
  (define-key evil-insert-state-map (kbd "C-k") 'kill-line)

  (define-key evil-normal-state-map (kbd "C-<") 'tab-line-switch-to-prev-tab)
  (define-key evil-normal-state-map (kbd "C->") 'tab-line-switch-to-next-tab)
  )

;; im-select.exe 的路径，可按需修改
(defvar my/im-select-path "d:/im-select.exe"
  "Path to im-select.exe on Windows.")

;; 定义一个函数，用于切换输入法至英文
(defun my/switch-to-english-input-method ()
  "调用 im-select.exe 将系统输入法切换为英文"
  (interactive)
  ;; 'call-process' 会同步调用外部程序
  (cond
   ((eq system-type 'windows-nt)
    (when (file-exists-p my/im-select-path)
      (call-process my/im-select-path nil nil nil "1033")))
   ((eq system-type 'gnu/linux)
    (when (executable-find "fcitx5-remote")
      (call-process "fcitx5-remote" nil nil nil "-c")))
   ((eq system-type 'darwin)
    (when (executable-find "fcitx5-remote")
      (call-process "fcitx5-remote" nil nil nil "-c")))
   (t
    (message "unknown system"))))

;; 将函数添加到 Evil 的 insert-state-exit-hook
(add-hook 'evil-insert-state-exit-hook 'my/switch-to-english-input-method)

(provide 'init-minimal)
;;; init-minimal.el ends here
