;;; init.el --- Profile 分发器 -*- lexical-binding: t -*-
;;
;; 启动链：early-init.el → init.el（本文件）→ init-full.el 或 init-minimal.el
;;
;; Profile 选择：
;;   全量（默认）  emacs
;;   精简          emacs --minimal     或设环境变量 EMACS_MINIMAL=1
;;   dump 映像     emacs-dump.cmd      或 emacs --dump-file=<.emacs.d>/emacs.pdmp

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; ---- Profile dispatch ----
;; `--minimal' 不是 Emacs 内置参数，须在此处从 command-line-args 删除，
;; 否则启动末尾报 "Unknown option"。
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
    (progn
      (message "Emacs 精简模式启动 (minimal profile)")
      (load (expand-file-name "init-minimal" user-emacs-directory)))
  (load (expand-file-name "init-full" user-emacs-directory)))

;;; init.el ends here
