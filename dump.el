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
        gc-cons-threshold most-positive-fixnum)
  ;; -Q 启动，load-path 里没有 lisp/；加进去才能 require 'init-mirrors。
  (add-to-list 'load-path (expand-file-name "lisp" root)))

(setq native-comp-jit-compilation nil)

;; ⚠ dump 期必须禁掉 subr trampoline（msys2/mingw64 的 Emacs 是 native-comp 构建才有此问题）。
;; 包在 require 时 advice 原语（select-window / read-key-sequence / all-completions…），
;; Emacs 会现场 native-compile 一个 trampoline .eln 到 `eln-cache/' 并加载；这个 comp unit
;; 会被烤进映像，启动 --dump-file 时 pdumper 要把它 LoadLibrary 回来却解析不到路径，直接
;; `Error using execdir …: 找不到指定的模块' 起不来。
;; 转储前再恢复成 t（见文件末尾），让映像在运行期仍能正常 advice 原语。
;;
;; 历史坑：这里曾试图改用「清空 `native-comp-eln-load-path'」来避免 .eln 进映像——那条路
;; 不通，映像加载时会段错误（0xC0000005）。清空既拦不住已加载的 AOT comp unit，也没有
;; 防御价值，别再走回去。禁 trampoline 才是对的开关。
(defvar my/dump--trampolines native-comp-enable-subr-trampolines)
(setq native-comp-enable-subr-trampolines nil)

;; 与 early-init 同逻辑：新机器无 keyring 时关签名校验，避免装/读包失败
(unless (file-exists-p (expand-file-name "elpa/gnupg/pubring.kbx" user-emacs-directory))
  (setq package-check-signature nil))

(require 'package)
(require 'init-mirrors)                 ; package-archives 的唯一定义处

;; ⚠ 必须复位后再 package-initialize，否则会静默少烤一大半包。
;; 原因：Emacs 启动阶段（早于本文件被 -l 加载）已按**默认** `user-emacs-directory'
;; 跑过一轮 `package-activate-all'。从 Git Bash / make 里跑时 HOME 被设成
;; C:\Users\Administrator，`~/.emacs.d' 于是不再是本仓库（%APPDATA%\.emacs.d），
;; 那边残留的过期 package-quickstart.el 被当成激活清单读进来，结果只激活到零星几个包；
;; 后面 my/dump-packages 的 require 便大批 file-missing，转储出一个「看着成功」的残缺映像。
;; 对策：把 quickstart 指回本仓库（那里没有该文件 → 走真正的目录扫描），
;; 并清空 package 记账，强制按本仓库 elpa/ 重新激活一遍。
(setq package-quickstart nil
      package-quickstart-file (expand-file-name "package-quickstart.el" user-emacs-directory)
      package--initialized nil
      package--activated nil
      package-alist nil
      package-activated-list nil)
(package-initialize)
(message "dump: 已激活 %d/%d 个包（elpa: %s）"
         (length package-activated-list) (length package-alist) package-user-dir)

;; evil-want-* 必须在 evil 加载【前】设好（尤其 evil-want-keybinding）。与 init-evil.el 顶部一致：
;; 用默认 t，让烤进映像的 evil 带上自带的 evil-keybindings.el（已移除 evil-collection）。
(setq evil-want-integration t
      evil-want-keybinding t
      evil-shift-width 2
      evil-search-module 'evil-search
      evil-respect-visual-line-mode t
      evil-cross-lines t
      evil-undo-system 'undo-redo)

;; 预加载集。每个包独立 condition-case：失败只跳过，不中断转储。
;; 核心组（启动期，最稳）+ 加分组（常用重包；若转储报错优先从加分组里删）。
(defvar my/dump-packages
  '(;; --- 核心 ---
    evil evil-surround evil-visualstar evil-commentary
    vertico marginalia consult embark embark-consult orderless
    corfu cape hydra project
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

;; 恢复 trampoline 开关：只在 dump 构建期禁用，映像本身要带回默认值，
;; 否则启动后 advice 原语的包（vertico/consult/evil…）会失效。
(setq native-comp-enable-subr-trampolines my/dump--trampolines)

(let ((out (expand-file-name "emacs.pdmp" user-emacs-directory)))
  (message "dump: 开始转储 -> %s" out)
  (dump-emacs-portable out))

;;; dump.el ends here
