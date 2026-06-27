;; early-init.el   -*- lexical-binding: t -*-

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6) ; 可选：当内存使用达到此百分比时也触发GC

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 20 1024 1024)) ; 例如设置为 20MB
            (setq gc-cons-percentage 0.1)))

;; Prevent unwanted runtime compilation for gccemacs (native-comp) users;
;; packages are compiled ahead-of-time when they are installed and site files
;; are compiled when gccemacs is installed.
(setq native-comp-jit-compilation nil)

;; Package initialize occurs automatically, before `user-init-file' is
;; loaded, but after `early-init-file'. We handle package
;; initialization, so we must prevent Emacs from doing it early!
(setq package-enable-at-startup nil)

;; 新机器首次装包时本地还没有 GnuPG keyring，GNU ELPA 的签名校验会因
;; "No public key" 失败，导致 compat / eglot 等已签名包无法安装，并连累
;; 所有依赖它们的包（consult/vertico/corfu/magit ...）。
;; 仅当本地没有 keyring 时关闭签名校验；一旦机器有了 keyring（如 Linux
;; 机器已导入 GNU ELPA 公钥），仍按默认进行校验。
(when (not (file-exists-p
            (expand-file-name "elpa/gnupg/pubring.kbx" user-emacs-directory)))
  (setq package-check-signature nil))

;; `use-package' is builtin since 29; set before loading `use-package'.
(defvar use-package-enable-imenu-support)
(setq use-package-enable-imenu-support t)

;; In noninteractive sessions, prioritize non-byte-compiled source files to
;; prevent the use of stale byte-code. Otherwise, it saves us a little IO time
;; to skip the mtime checks on every *.elc file.
(setq load-prefer-newer noninteractive)

;; Explicitly set the prefered coding systems to avoid annoying prompt
;; from emacs (especially on Microsoft Windows)
(prefer-coding-system 'utf-8)

;; Windows: avoid GC pauses caused by compacting font caches (Nerd Fonts etc.)
(setq inhibit-compacting-font-caches t)

;; Inhibit resizing frame
(setq frame-inhibit-implied-resize t)

;; Faster to disable these here (before they've been initialized)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(when (featurep 'ns)
  (push '(ns-transparent-titlebar . t) default-frame-alist))
(setq-default mode-line-format nil)

;; 禁用 GNU 启动屏（dashboard 首屏已关，避免回退到默认 splash）
(setq inhibit-startup-screen t)

;; Initial frame
;; (setq initial-frame-alist '((top . 0.5)
;;                             (left . 0.5)
;;                             (width . 0.7)
;;                             (height . 0.85)
;;                             (fullscreen)))
