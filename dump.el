;;; dump.el --- 构建自定义 portable dump 加速启动 -*- lexical-binding: t; -*-
;;
;; 用法：  emacs --batch -Q -l dump.el      → 生成 emacs.pdmp
;; 启动：  emacs --dump-file=<.emacs.d>/emacs.pdmp   （或用 emacs-dump.cmd）
;;
;; 原理：自定义 dump 是标准 dump 的超集——这里把启动期/常用重包 require 进来，再转储成映像。
;; 启动时 early-init/init 照常运行，config 里的 (require ...) 因已在映像中而瞬间返回。
;; 注意：只预加载第三方库，不在 dump 期跑用户 init（dump 期无 GUI，跑 init 会踩字体/frame/主题的坑）。

(let ((root (file-name-directory (or load-file-name buffer-file-name default-directory))))
  (setq user-emacs-directory (file-name-as-directory root)
        package-user-dir (expand-file-name "elpa" root)
        gc-cons-threshold most-positive-fixnum))

;; dump 里不能含 .eln（native-comp）引用：加载 dump 时 LoadLibrary 调用时序早于
;; Windows DLL 搜索路径完全建立，会报 "找不到指定的模块"。清空 eln-load-path
;; 让包在 dump 构建期只加载字节编译版本，不把 .eln 地址烤进映像。
(setq native-comp-jit-compilation nil)
(when (boundp 'native-comp-eln-load-path)
  (setq native-comp-eln-load-path nil))

;; 与 early-init 同逻辑：新机器无 keyring 时关签名校验，避免装/读包失败
(unless (file-exists-p (expand-file-name "elpa/gnupg/pubring.kbx" user-emacs-directory))
  (setq package-check-signature nil))

(require 'package)
(setq package-archives '(("gnu"    . "https://mirrors.ustc.edu.cn/elpa/gnu/")
                         ("melpa"  . "https://mirrors.ustc.edu.cn/elpa/melpa/")
                         ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")
                         ("org"    . "https://mirrors.ustc.edu.cn/elpa/org/")))
(package-initialize)

;; evil-want-* 必须在 evil 加载【前】设好（尤其 evil-want-keybinding）。否则烤进映像的 evil
;; 会以默认值加载，启动时 evil-collection 报 issue #60。与 init-evil.el 顶部保持一致。
(setq evil-want-integration t
      evil-want-keybinding nil
      evil-shift-width 2
      evil-search-module 'evil-search
      evil-respect-visual-line-mode t
      evil-cross-lines t
      evil-undo-system 'undo-redo)

;; 预加载集。每个包独立 condition-case：失败只跳过，不中断转储。
;; 核心组（启动期，最稳）+ 加分组（常用重包；若转储报错优先从加分组里删）。
(defvar my/dump-packages
  '(;; --- 核心 ---
    evil evil-collection evil-surround evil-visualstar evil-commentary
    vertico marginalia consult embark embark-consult orderless
    corfu cape doom-themes hydra project
    ;; --- 加分 ---
    ;; eat 含 C 扩展（eat-core.dll），烤进 dump 后恢复时可能触发段错误，排除在外
    eglot magit popper ace-window)
  "要烤进 dump 的包；从前到后加载。")

(let ((loaded 0) (skipped '()))
  (dolist (pkg my/dump-packages)
    (condition-case err
        (progn (require pkg) (setq loaded (1+ loaded)))
      (error (push pkg skipped)
             (message "dump: 跳过 %s (%S)" pkg err))))
  (message "dump: 预加载 %d 个包，跳过 %d 个 %S" loaded (length skipped) skipped))

;; 转储前清理：pdumper 不支持 overlay；某些包加载时会在缓冲区里建 overlay。
;; 删掉所有 overlay（纯显示态，运行时会按需重建，不影响烤进映像的代码）。
(dolist (buf (buffer-list))
  (with-current-buffer buf
    (remove-overlays)))

;; 关键：dump-emacs-portable 会丢掉 load-path 的运行期追加，却保留 package-activated-list。
;; 若不处理，启动时 package-initialize 见到「已激活」便跳过，不再把包目录加回 load-path，
;; 导致没烤进映像的包（如 fd-dired）找不到、init.el 中途报错。
;; 解决：复位整套 package 记账，让启动时 init.el 的 (package-initialize) 从头重建 load-path。
;; 已烤进映像的包代码仍在内存（featurep t），require 照样瞬返；这里只重置记账，不卸载代码。
(setq package--initialized nil
      package-activated-list nil
      package-alist nil)

(let ((out (expand-file-name "emacs.pdmp" user-emacs-directory)))
  (message "dump: 开始转储 -> %s" out)
  (dump-emacs-portable out))

;;; dump.el ends here
