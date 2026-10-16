;; early-init.el   -*- lexical-binding: t -*-

(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6)

;; ⚠ 启动后交给 gcmh 动态管；不手动收窄成固定值（固定 20MB 在 eglot/jsonrpc/tree-sitter 下偏低，Automatic GC 明显）
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-percentage 0.1)))

;; native-comp：本机是带 native-comp 的 AOT 构建，开 JIT（首次/装包后有后台 CPU 属正常）；告警只写 *Warnings*
(setq native-comp-jit-compilation t)
(setq native-comp-async-report-warnings-errors 'silent)

;; ⚠ 必须在 user-lisp 自动字节编译之前激活包，否则编译时 evil/gcmh 未激活、*Compile-Log* 报错
;; ⚠ 只用 package-activate-all 走 quickstart；不能再调 package-initialize（会抵消 quickstart 收益）
(setq package-enable-at-startup nil)
(require 'package)
(setq package-quickstart t
      ;; 放 var/（避开根目录旧快照被当激活清单读走）
      package-quickstart-file (expand-file-name "var/package-quickstart.el" user-emacs-directory))
(unless (or (file-exists-p package-quickstart-file)
            (file-exists-p (concat package-quickstart-file "c")))
  (make-directory (file-name-directory package-quickstart-file) t)
  (package-quickstart-refresh))
(package-activate-all)

;; ⚠ 收窄编译告警：延迟加载必然产生成片 free-vars/unresolved（真错误仍会暴露）
(setq byte-compile-warnings '(not free-vars unresolved obsolete interactive-only lexical))

(setq inhibit-redisplay t)
(setq inhibit-message t)
(add-hook 'window-setup-hook
          (lambda () (setq inhibit-redisplay nil inhibit-message nil))
          100)

;; ⚠ 本地还没 keyring 时关签名校验（否则 GNU ELPA 已签名包装不上、连累依赖它们的包）
(when (not (file-exists-p
            (expand-file-name "elpa/gnupg/pubring.kbx" user-emacs-directory)))
  (setq package-check-signature nil))

;; 先 defvar 再 set，避免编译告警
(defvar use-package-enable-imenu-support)
(setq use-package-enable-imenu-support t)

;; 交互会话优先 .elc；--batch 下用源码（避免陈旧字节码）
(setq load-prefer-newer noninteractive)

(prefer-coding-system 'utf-8)

;; ⚠ 子进程输出钉死 utf-8：consult-*grep 的 --null 输出含 NUL，undecided 探测会判成二进制、中文变八进制转义
(setq default-process-coding-system '(utf-8 . utf-8))

;; Windows：避免压缩字体缓存引起 GC 停顿
(setq inhibit-compacting-font-caches t)

;; ⚠ 必须用绝对路径 load：user-lisp 的 load-path 要到更晚的启动阶段才建立
(load (expand-file-name "user-lisp/init-windows" user-emacs-directory))
(load (expand-file-name "user-lisp/evil-plugins/ime" user-emacs-directory))

(setq frame-inhibit-implied-resize t)

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(when (featurep 'ns)
  (push '(ns-transparent-titlebar . t) default-frame-alist))
(setq-default mode-line-format nil)

(setq inhibit-startup-screen t)

