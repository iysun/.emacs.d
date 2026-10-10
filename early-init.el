;; early-init.el   -*- lexical-binding: t -*-

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6) ; 可选：当内存使用达到此百分比时也触发GC

;; 启动完成后 gc-cons-threshold 交给 gcmh 动态管理（见 user-lisp/init-base.el），
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
(setq native-comp-jit-compilation t)
(setq native-comp-async-report-warnings-errors 'silent)

;; 自己初始化包，而不是让 Emacs 自动激活：放这里只做一次，且必须早于 user-lisp 的
;; 自动字节编译——否则编译时 evil / gcmh 等未激活，会失败并把错误刷进 *Compile-Log*。
;; 关掉 Emacs 的自动激活（`package-enable-at-startup'），否则会与下面显式那次重复：
;; `package-initialize' 每次都做 load-all-descriptors + read-archive-contents +
;; package-activate-all + build-compatibility-table，纯浪费。
(setq package-enable-at-startup nil)
(require 'package)
(package-initialize)

;; user-lisp 会自动字节编译 user-lisp/ 下所有文件。本配置大量「先 setq 包变量、
;; 包用的时候才加载」以及调用 autoload 函数，编译期必然产生成片
;; free-vars（赋值自由变量）/ unresolved（调用未知函数）等告警——都是延迟加载的
;; 正常现象，不是错误。收窄编译告警类别，避免 *Compile-Log* 每次启动刷屏；
;; 真正的语法错误、宏用错（Invalid function）等仍会暴露（运行时也会立刻报）。
(setq byte-compile-warnings '(not free-vars unresolved obsolete interactive-only lexical))

;; init 期间不重绘、不回显，首帧出来更快；`window-setup-hook' 时恢复（zdn 同款做法）。
(setq inhibit-redisplay t)
(setq inhibit-message t)
(add-hook 'window-setup-hook
          (lambda () (setq inhibit-redisplay nil inhibit-message nil))
          100)

;; 新机器首次装包时本地还没有 GnuPG keyring，GNU ELPA 的签名校验会因
;; "No public key" 失败，导致 compat / eglot 等已签名包无法安装，并连累
;; 所有依赖它们的包（consult/vertico/corfu ...）。
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

;; Windows 专项设置（user-lisp/init-windows.el，非 Windows 平台空操作）+ 跨平台
;; 输入法切换（user-lisp/evil-plugins/ime.el）。这两个要在最早期加载，而 user-lisp 的
;; load-path 由 `prepare-user-lisp' 在更晚的启动阶段才建立，故这里仍用绝对路径 `load'。
(load (expand-file-name "user-lisp/init-windows" user-emacs-directory))
(load (expand-file-name "user-lisp/evil-plugins/ime" user-emacs-directory))

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
