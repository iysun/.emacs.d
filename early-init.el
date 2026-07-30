;; early-init.el   -*- lexical-binding: t -*-

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6) ; 可选：当内存使用达到此百分比时也触发GC

;; 启动完成后 gc-cons-threshold 交给 gcmh 动态管理（见 lisp/init-base.el），
;; 这里不再手动收紧到固定值：固定 20MB 在 eglot/jsonrpc/tree-sitter 频繁产生
;; 垃圾的场景下偏低，profiler 里能看到明显的 Automatic GC 占比、敲字卡顿。
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-percentage 0.1)))

;; native-comp：本机 Emacs 由 msys2/mingw64 提供，是带 native-comp 的 AOT 构建
;; （旧的 scoop 版没有 native-comp，这里曾设成 nil，在那台构建上纯属空操作）。
;; 开着 JIT，elpa 里的包会在后台逐步编译进 `eln-cache/'，之后运行更快；
;; 首次启动/装包后会有一段后台 CPU 占用，属正常。
;; 编译告警只写 *Warnings*，不自动弹缓冲区（第三方包的告警干扰太多）。
;; ⚠ dump 构建期是另一回事：`dump.el' 会关掉 JIT 和 subr trampoline，原因见该文件注释。
(setq native-comp-jit-compilation t)
(setq native-comp-async-report-warnings-errors 'silent)

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

;; Windows 专项设置（lisp/init-windows.el，非 Windows 平台空操作）+ 跨平台输入法
;; 切换（lisp/init-ime.el，全量/精简两套 profile 共用一份）。这里 `lisp/' 还没
;; 进 load-path（那是 init.el 干的事），用绝对路径 `load'。
(load (expand-file-name "lisp/init-windows" user-emacs-directory))
(load (expand-file-name "lisp/init-ime" user-emacs-directory))

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
