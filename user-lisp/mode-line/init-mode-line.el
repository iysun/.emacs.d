;; user-lisp/mode-line/init-mode-line.el 	-*- lexical-binding: t -*-

(defun my-ui--ml-truncate (str &optional limit)
  "STR 超过 LIMIT（默认 20）字符时截断并加省略号。
对应 emacs-solo 的 `emacs-solo/shorten-vc-mode'，避免长分支名/项目名把
mode-line 挤爆。"
  (let ((limit (or limit 20)))
    (if (> (length str) limit)
        (concat (substring str 0 limit) (if (char-displayable-p ?…) "…" "..."))
      str)))

(defun my-ui--ml-click (text help cmd)
  "把 TEXT 包成可点击段：悬浮显示 HELP，鼠标左键执行 CMD。"
  (propertize text
              'mouse-face 'mode-line-highlight
              'help-echo help
              'local-map (let ((m (make-sparse-keymap)))
                           (define-key m [mode-line mouse-1] cmd)
                           m)))

(defvar-local my-ui--ml-vc-cache nil)
(defvar-local my-ui--ml-project-cache nil)

(defun my-ui-ml-vc ()
  "分支名（纯文字，不带图标——对齐 emacs-solo 全篇无图标的风格）。点击开 vc-dir。"
  (or my-ui--ml-vc-cache
      (setq my-ui--ml-vc-cache
            (let* ((root (ignore-errors (vc-root-dir)))
                   (backend (and root (ignore-errors (vc-responsible-backend root))))
                   (branch (if backend
                               (let ((b (replace-regexp-in-string
                                         "\\`[A-Za-z]+[-:] ?" ""
                                         (or (ignore-errors
                                               (vc-call-backend backend 'mode-line-string root))
                                             ""))))
                                 (if (string-empty-p b) "?" b))
                             "-")))
              (my-ui--ml-click
               (my-ui--ml-truncate (substring-no-properties branch))
               "mouse-1: vc-dir"
               #'vc-dir)))))

(defun my-ui-ml-project ()
  "当前 project 名。点击切换 project，不在 project 里时不显示。
仿 emacs-solo 的 project 段（那边用内建 `project-mode-line-format'，这里为
了跟 VC 段等其余分段风格一致，改成自定义函数 + buffer-local 缓存）。"
  (or my-ui--ml-project-cache
      (setq my-ui--ml-project-cache
            (let ((proj (ignore-errors (project-current))))
              (if proj
                  (my-ui--ml-click
                   (my-ui--ml-truncate
                    (if (fboundp 'project-name)
                        (project-name proj)
                      (file-name-nondirectory
                       (directory-file-name (project-root proj)))))
                   "mouse-1: 切换 project"
                   #'project-switch-project)
                "")))))

(define-advice vc-refresh-state (:after (&rest _) my-ui-reset-vc-cache)
  (setq my-ui--ml-vc-cache nil))

;; ⚠ 不关掉 evil 会往共享 mode-line-format 插标签，一改全 buffer 变
(with-eval-after-load 'evil
  (setq evil-mode-line-format nil))

(defconst my-ui-mode-line-format
  '("%e" "  "
    (:propertize
     (:eval (if (char-displayable-p ?λ) "λ  " "   "))
     face font-lock-keyword-face)
    (:eval (if (bound-and-true-p evil-local-mode)
               (format "%s " evil-mode-line-tag)
             ""))
    mode-line-frame-identification
    mode-line-buffer-identification
    "   "
    mode-line-position
    mode-line-format-right-align
    "  "
    (:eval (my-ui-ml-project))
    "  "
    (:eval (my-ui-ml-vc))
    "  "
      ;; ⚠ 非 flymake buffer 求值会抛 user-error
    (:eval (and (bound-and-true-p flymake-mode) flymake-mode-line-counters))
    "  "
    mode-line-misc-info
    "  "))

(setq-default mode-line-buffer-identification '(" %b")
              mode-line-position-column-line-format '(" %l:%c"))

(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook dired-mode-hook))
  (add-hook hook (lambda ()
                   (setq my-ui--ml-vc-cache nil
                         my-ui--ml-project-cache nil)
                   (setq-local mode-line-format my-ui-mode-line-format))))

(provide 'init-mode-line)
