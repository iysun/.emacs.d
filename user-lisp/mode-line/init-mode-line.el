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
                         my-ui--ml-project-cache nil))))

;; 状态写进 *Minibuf-0*：空闲时这一行本来是空的，只给 echo area 加
;; after-string 不会显示。左段靠左，右段用 :align-to 贴到右边。
;; ⚠ 正在读 minibuffer / isearch 时不要改 *Minibuf-0*，输入就在这一行。
(defvar my-ui--tray-timer nil)
(defvar my-ui--tray-updating nil)
(defvar my-ui-echo-tray-mode nil)

(defun my-ui--tray-keep (s)
  "去掉 S 上的鼠标绑定。空白和占位 \"-\" 返回 nil。"
  (when (stringp s)
    (let ((plain (string-trim (substring-no-properties s))))
      (unless (or (string-empty-p plain) (string= plain "-"))
        (let ((copy (copy-sequence s)))
          (remove-text-properties 0 (length copy)
                                  '(mouse-face nil help-echo nil local-map nil keymap nil)
                                  copy)
          (setq copy (replace-regexp-in-string "[\n\r]+" " " copy))
          (string-trim copy))))))

(defun my-ui--tray-join (parts)
  (let ((xs (delq nil parts)))
    (when xs (mapconcat #'identity xs "  "))))

(defun my-ui--tray-color (text face)
  "给 TEXT 叠上 FACE。用主题已有的 font-lock 颜色，不另配一套。"
  (when (and (stringp text) (not (string-empty-p text)))
    (add-face-text-property 0 (length text) face nil text))
  text)

(defun my-ui--tray-evil ()
  (when (bound-and-true-p evil-local-mode)
    (my-ui--tray-color (my-ui--tray-keep evil-mode-line-tag)
                       'font-lock-keyword-face)))

(defun my-ui--tray-buffer ()
  (my-ui--tray-color (my-ui--ml-truncate (buffer-name) 24)
                     'font-lock-function-name-face))

(defun my-ui--tray-position ()
  (format "%d:%d" (line-number-at-pos) (current-column)))

(defun my-ui--tray-flymake ()
  (when (and (bound-and-true-p flymake-mode)
             (boundp 'flymake-mode-line-counters))
    (ignore-errors
      (my-ui--tray-keep (format-mode-line flymake-mode-line-counters)))))

(defun my-ui--tray-left ()
  "原 mode-line 左段：Evil 状态、缓冲区名、行号列号。"
  (let ((s (my-ui--tray-join
            (list (my-ui--tray-evil)
                  (my-ui--tray-buffer)
                  (my-ui--tray-position)))))
    (when s (concat "  " s))))

(defun my-ui--tray-right ()
  "原 mode-line 右段：项目、分支、Flymake。"
  (my-ui--tray-join
   (list (my-ui--tray-keep (my-ui-ml-project))
         (my-ui--tray-color (my-ui--tray-keep (my-ui-ml-vc))
                            'font-lock-string-face)
         (my-ui--tray-flymake))))

(defun my-ui--echo-width ()
  "这一行的可用列数。留 1 列，避免最后一个字换行。"
  (let ((win (minibuffer-window)))
    (if (window-live-p win)
        (max 0 (1- (window-body-width win)))
      0)))

(defun my-ui--tray-ellipsis ()
  (if (char-displayable-p ?…) "…" "..."))

(defun my-ui--tray-line (left right)
  "LEFT 从行首开始，RIGHT 对齐到行尾。"
  (setq left (or left ""))
  (setq right (or right ""))
  (if (string-empty-p right)
      left
    (let* ((rw (string-width right))
           (pad (propertize " " 'cursor 1
                            'display `(space :align-to (- right-fringe ,(+ rw 2))))))
      (concat left pad right))))

(defun my-ui--tray-render ()
  "左段靠左、右段靠右的一整行。"
  (let* ((width (max 1 (my-ui--echo-width)))
         (left (or (my-ui--tray-left) ""))
         (right (or (my-ui--tray-right) ""))
         (gap 2))
    (when (> (+ (string-width left) gap (string-width right)) width)
      (let ((room (max 0 (- width (string-width left) gap))))
        (setq right (if (zerop room)
                        ""
                      (truncate-string-to-width right room nil nil (my-ui--tray-ellipsis))))))
    (when (> (string-width left) (1- width))
      (setq left (truncate-string-to-width left (1- width) nil nil (my-ui--tray-ellipsis)))
      (setq right ""))
    (my-ui--tray-line left right)))

(defvar my-ui--tray-resize-saved nil)
(defvar my-ui--tray-resize-locked nil)

(defun my-ui--tray-pad ()
  "和 tab-line 用同一套上下内边距。上边距在分割线里，下边距是 line-spacing。"
  (if (boundp 'my-ui-bar-padding) my-ui-bar-padding 2))

(defun my-ui--tray-target-height ()
  "状态文字这一行的像素高度：字高 + 下边距。
加上分割线里的上边距之后，和 tab-line（字高 + 上下边距）一样高。亮线本身不算在内。"
  (+ (default-font-height) (my-ui--tray-pad)))

(defun my-ui--tray-lock-resize ()
  "提示消息不要改 minibuffer 高度，否则 :w 时这一行会跳。"
  (unless my-ui--tray-resize-locked
    (setq my-ui--tray-resize-saved resize-mini-windows
          my-ui--tray-resize-locked t))
  (setq resize-mini-windows nil))

(defun my-ui--tray-unlock-resize ()
  (when my-ui--tray-resize-locked
    (setq resize-mini-windows my-ui--tray-resize-saved
          my-ui--tray-resize-locked nil)))

(defun my-ui--tray-fit-height ()
  "把空闲 minibuffer 固定到 `my-ui--tray-target-height'。
正在显示提示或正在输入时不动，避免和回显抢高度。
`window-resize' 默认把像素收成整行，这里临时打开 `window-resize-pixelwise'。"
  (when (and my-ui-echo-tray-mode
             (not (active-minibuffer-window))
             (not (current-message)))
    (let ((win (minibuffer-window)))
      (when (window-live-p win)
        (let ((delta (- (my-ui--tray-target-height)
                        (window-pixel-height win))))
          (unless (zerop delta)
            (condition-case nil
                (let ((window-resize-pixelwise t))
                  (window-resize win delta nil nil t))
              (error nil))))))))

(defun my-ui--echo-tray-suppressed-p ()
  (or (active-minibuffer-window)
      (bound-and-true-p isearch-mode)))

(defun my-ui--tray-bar-bg ()
  "和 tab-line 那条 bar 同一个背景，上下 padding 才是同一块颜色。"
  (let ((c (cond
            ((fboundp 'my-ui--bg-of) (my-ui--bg-of 'tab-line))
            ((facep 'tab-line) (face-background 'tab-line nil t)))))
    (and (stringp c) (not (string-prefix-p "unspecified" c)) c)))

(defun my-ui--tray-style-buffer (buf)
  "底色、下边距跟 tab-line 对齐。只改托盘和回显用的 buffer，不影响正在输入的 minibuffer。"
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq-local cursor-type nil)
      (setq-local mode-line-format nil)
      (setq-local line-spacing (my-ui--tray-pad))
      (when-let* ((bg (my-ui--tray-bar-bg)))
        (setq-local face-remapping-alist `((default (:background ,bg))))))))

(defun my-ui--tray-set-minibuf (text)
  "把 TEXT 写进空闲 minibuffer。这个 buffer 空着时，底部那一行不会出现。"
  (let ((buf (get-buffer-create " *Minibuf-0*")))
    (my-ui--tray-style-buffer buf)
    (dolist (name '(" *Echo Area 0*" " *Echo Area 1*"))
      (my-ui--tray-style-buffer (get-buffer-create name)))
    (with-current-buffer buf
      (buffer-disable-undo)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (when (and text (not (string-empty-p text)))
          (insert text))
        (goto-char (point-min))))))

(defun my-ui--sync-mode-line ()
  "托盘开着时不显示 mode-line。关掉后，原来那几类 buffer 恢复自定义 mode-line。"
  (setq mode-line-format
        (cond
         ((minibufferp) nil)
         ((and (not my-ui-echo-tray-mode)
               (derived-mode-p 'prog-mode 'text-mode 'conf-mode 'dired-mode))
          my-ui-mode-line-format)
         (t nil))))

(defun my-ui--sync-all-mode-lines ()
  (setq-default mode-line-format nil)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (my-ui--sync-mode-line))))

(defun my-ui--echo-tray-update ()
  (unless (or my-ui--tray-updating (my-ui--echo-tray-suppressed-p))
    (let ((my-ui--tray-updating t))
      (let* ((win (or (minibuffer-selected-window) (selected-window)))
             (text (if (window-live-p win)
                       (with-current-buffer (window-buffer win)
                         (my-ui--tray-render))
                     "")))
        (my-ui--tray-set-minibuf text)
        (my-ui--tray-fit-height)))))

(defun my-ui--tray-on-minibuffer-setup ()
  (setq resize-mini-windows 'grow-only))

(defun my-ui--tray-on-minibuffer-exit ()
  (when my-ui--tray-resize-locked
    (setq resize-mini-windows nil))
  (my-ui--tray-fit-height))

(defun my-ui--echo-tray-enable ()
  (my-ui--sync-all-mode-lines)
  (my-ui--tray-lock-resize)
  (add-hook 'after-change-major-mode-hook #'my-ui--sync-mode-line)
  (add-hook 'post-command-hook #'my-ui--echo-tray-update)
  (add-hook 'echo-area-clear-hook #'my-ui--echo-tray-update)
  (add-hook 'minibuffer-setup-hook #'my-ui--tray-on-minibuffer-setup)
  (add-hook 'minibuffer-exit-hook #'my-ui--tray-on-minibuffer-exit)
  (unless my-ui--tray-timer
    (setq my-ui--tray-timer (run-with-timer 1 1 #'my-ui--echo-tray-update)))
  (when (fboundp 'my-ui-setup-bars)
    (my-ui-setup-bars))
  (when (fboundp 'my/update-bottom-divider)
    (my/update-bottom-divider))
  (my-ui--echo-tray-update))

(defun my-ui--echo-tray-disable ()
  (when my-ui--tray-timer
    (cancel-timer my-ui--tray-timer)
    (setq my-ui--tray-timer nil))
  (remove-hook 'post-command-hook #'my-ui--echo-tray-update)
  (remove-hook 'echo-area-clear-hook #'my-ui--echo-tray-update)
  (remove-hook 'after-change-major-mode-hook #'my-ui--sync-mode-line)
  (remove-hook 'minibuffer-setup-hook #'my-ui--tray-on-minibuffer-setup)
  (remove-hook 'minibuffer-exit-hook #'my-ui--tray-on-minibuffer-exit)
  (my-ui--tray-set-minibuf "")
  (my-ui--tray-unlock-resize)
  (my-ui--sync-all-mode-lines)
  (when (fboundp 'my/update-bottom-divider)
    (my/update-bottom-divider))
  (when (fboundp 'my-ui-setup-bars)
    (my-ui-setup-bars)))

(define-minor-mode my-ui-echo-tray-mode
  "把原 mode-line 显示在 minibuffer 这一行：左段靠左，右段靠右。
正在输入或 isearch 时先让出这一行。"
  :global t
  :group 'mode-line
  (if my-ui-echo-tray-mode
      (my-ui--echo-tray-enable)
    (my-ui--echo-tray-disable)))

(unless noninteractive
  (my-ui-echo-tray-mode 1))

(provide 'init-mode-line)
