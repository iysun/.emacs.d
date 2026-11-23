;; user-lisp/mode-line/init-mode-line.el 	-*- lexical-binding: t -*-

(defun iys/ui--ml-truncate (str &optional limit)
  "STR 超过 LIMIT（默认 20）字符时截断并加省略号。
对应 emacs-solo 的 `emacs-solo/shorten-vc-mode'，避免长分支名/项目名把
mode-line 挤爆。"
  (let ((limit (or limit 20)))
    (if (> (length str) limit)
        (concat (substring str 0 limit) (if (char-displayable-p ?…) "…" "..."))
      str)))

(defun iys/ui--ml-click (text help cmd)
  "把 TEXT 包成可点击段：悬浮显示 HELP，鼠标左键执行 CMD。
同一个串既进 mode-line 也进回声区托盘，两处的事件不一样：mode-line 里带
`mode-line' 区域前缀，回声区是普通文本、只有裸 `mouse-1'（见 button.el 里
`<mode-line> <mouse-2>' 与 `<mouse-2>' 分开绑的注释），所以两套都绑。"
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] cmd)
    (define-key map [mouse-1] cmd)
    (define-key map [follow-link] 'mouse-face)
    (propertize text
                'mouse-face 'mode-line-highlight
                'help-echo help
                'local-map map)))

(defvar-local iys/ui--ml-vc-cache nil)
(defvar-local iys/ui--ml-project-cache nil)

(defun iys/ui-ml-vc ()
  "分支名（纯文字，不带图标——对齐 emacs-solo 全篇无图标的风格）。点击开 vc-dir。"
  (or iys/ui--ml-vc-cache
      (setq iys/ui--ml-vc-cache
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
              (iys/ui--ml-click
               (iys/ui--ml-truncate (substring-no-properties branch))
               "mouse-1: vc-dir"
               #'vc-dir)))))

(defun iys/ui-ml-project ()
  "当前 project 名。点击切换 project，不在 project 里时不显示。
仿 emacs-solo 的 project 段（那边用内建 `project-mode-line-format'，这里为
了跟 VC 段等其余分段风格一致，改成自定义函数 + buffer-local 缓存）。"
  (or iys/ui--ml-project-cache
      (setq iys/ui--ml-project-cache
            (let ((proj (ignore-errors (project-current))))
              (if proj
                  (iys/ui--ml-click
                   (iys/ui--ml-truncate
                    (if (fboundp 'project-name)
                        (project-name proj)
                      (file-name-nondirectory
                       (directory-file-name (project-root proj)))))
                   "mouse-1: 切换 project"
                   #'project-switch-project)
                "")))))

(define-advice vc-refresh-state (:after (&rest _) iys/ui-reset-vc-cache)
  (setq iys/ui--ml-vc-cache nil))

;; ⚠ 不关掉 evil 会往共享 mode-line-format 插标签，一改全 buffer 变
(with-eval-after-load 'evil
  (setq evil-mode-line-format nil))

(defconst iys/ui-mode-line-format
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
    (:eval (iys/ui-ml-project))
    "  "
    (:eval (iys/ui-ml-vc))
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
                   (setq iys/ui--ml-vc-cache nil
                         iys/ui--ml-project-cache nil))))

;; 状态写进 *Minibuf-0*：空闲时这一行本来是空的，只给 echo area 加
;; after-string 不会显示。左段靠左，右段用 :align-to 贴到右边。
;; ⚠ 正在读 minibuffer / isearch 时不要改 *Minibuf-0*，输入就在这一行。
(defvar iys/ui--tray-timer nil)
(defvar iys/ui--tray-updating nil)

(defun iys/ui--tray-keep (s &optional keep-click)
  "去掉 S 上的鼠标绑定。空白和占位 \"-\" 返回 nil。
KEEP-CLICK 非 nil 时保留 local-map/help-echo/mouse-face —— 那是
`iys/ui--ml-click' 自己包的可点击段，托盘里要能点。"
  (when (stringp s)
    (let ((plain (string-trim (substring-no-properties s))))
      (unless (or (string-empty-p plain) (string= plain "-"))
        (let ((copy (copy-sequence s)))
          (unless keep-click
            (remove-text-properties 0 (length copy)
                                    '(mouse-face nil help-echo nil local-map nil keymap nil)
                                    copy))
          (setq copy (replace-regexp-in-string "[\n\r]+" " " copy))
          (string-trim copy))))))

(defun iys/ui--tray-join (parts)
  (let ((xs (delq nil parts)))
    (when xs (mapconcat #'identity xs "  "))))

(defun iys/ui--tray-color (text face)
  "给 TEXT 叠上 FACE。用主题已有的 font-lock 颜色，不另配一套。"
  (when (and (stringp text) (not (string-empty-p text)))
    (add-face-text-property 0 (length text) face nil text))
  text)

(defun iys/ui--tray-evil ()
  (when (bound-and-true-p evil-local-mode)
    (iys/ui--tray-color (iys/ui--tray-keep evil-mode-line-tag)
                       'font-lock-keyword-face)))

(defun iys/ui--tray-buffer ()
  (iys/ui--tray-color (iys/ui--ml-truncate (buffer-name) 24)
                     'font-lock-function-name-face))

(defun iys/ui--tray-position ()
  (format "%d:%d" (line-number-at-pos) (current-column)))

(defun iys/ui--tray-flymake ()
  (when (and (bound-and-true-p flymake-mode)
             (boundp 'flymake-mode-line-counters))
    (ignore-errors
      (iys/ui--tray-keep (format-mode-line flymake-mode-line-counters)))))

(defun iys/ui--tray-left ()
  "原 mode-line 左段：Evil 状态、缓冲区名、行号列号。"
  (let ((s (iys/ui--tray-join
            (list (iys/ui--tray-evil)
                  (iys/ui--tray-buffer)
                  (iys/ui--tray-position)))))
    (when s (concat "  " s))))

(defun iys/ui--tray-right ()
  "原 mode-line 右段：项目、分支、Flymake。
项目/分支带 `iys/ui--ml-click' 的点击绑定，托盘里也要能点，故 KEEP-CLICK。"
  (iys/ui--tray-join
   (list (iys/ui--tray-keep (iys/ui-ml-project) t)
         (iys/ui--tray-color (iys/ui--tray-keep (iys/ui-ml-vc) t)
                            'font-lock-string-face)
         (iys/ui--tray-flymake))))

(defvar iys/ui--tray-message nil
  "接管下来的 echo 消息（原样一段，可能多行），nil 表示没有。")
(defvar iys/ui--tray-message-timer nil)
(defvar iys/ui--tray-message-duration 1
  "消息在托盘行里停留的秒数，到点自动让位给状态段。")
(defvar iys/ui--tray-message-max-width 40
  "消息最多占多少列，超过就截断加省略号。
挡住 eldoc 签名、which-key 提示这类长串，别让它把整行吃掉。")

(defun iys/ui--tray-message-line ()
  "把接管的 echo 消息压成一行、去掉属性，按 `iys/ui--tray-message-max-width'
截断后接在左段状态后面。"
  (when (stringp iys/ui--tray-message)
    (let ((s (string-trim
              (replace-regexp-in-string
               "[\n\r]+" " " (substring-no-properties iys/ui--tray-message)))))
      (unless (string-empty-p s)
        (truncate-string-to-width s iys/ui--tray-message-max-width
                                  nil nil (iys/ui--tray-ellipsis))))))

(defun iys/ui--tray-left-with-message (room)
  "左段状态，有 echo 消息时接在后面——消息不顶掉状态。
ROOM 是这一行「状态 + 消息」能用的列数（已扣掉右段），消息超了就截断加
省略号，保证右段不会被顶出可视范围。"
  (let* ((status (iys/ui--tray-left))
         (msg (iys/ui--tray-message-line))
         (budget (and msg room (- room (string-width (or status "")) 2)))
         (msg (when (and msg budget (> budget 0))
                (truncate-string-to-width msg budget nil nil (iys/ui--tray-ellipsis)))))
    (cond ((and status msg) (concat status "  " msg))
          (msg (concat "  " msg))
          (status status)
          (t ""))))

(defun iys/ui--echo-width ()
  "这一行的可用列数。留 1 列，避免最后一个字换行。"
  (let ((win (minibuffer-window)))
    (if (window-live-p win)
        (max 0 (1- (window-body-width win)))
      0)))

(defun iys/ui--tray-ellipsis ()
  (if (char-displayable-p ?…) "…" "..."))

(defun iys/ui--tray-line (left right)
  "LEFT 从行首开始，RIGHT 对齐到行尾。"
  (setq left (or left ""))
  (setq right (or right ""))
  (if (string-empty-p right)
      left
    (let* ((rw (string-width right))
           (pad (propertize " " 'cursor 1
                            'display `(space :align-to (- right-fringe ,(+ rw 2))))))
      (concat left pad right))))

(defun iys/ui--tray-render ()
  "左段靠左、右段靠右的一整行。
echo 消息接在左段状态后面（不顶掉状态），另外还受 `iys/ui--tray-message-max-width'
和「先给右段留位」两条限制，所以再长的消息也不会把项目/分支顶出可视范围。"
  (let* ((width (max 1 (iys/ui--echo-width)))
         (right (or (iys/ui--tray-right) ""))
         (gap 2)
         (left (iys/ui--tray-left-with-message
                (- width (string-width right) gap))))
    (when (> (+ (string-width left) gap (string-width right)) width)
      (let ((room (max 0 (- width (string-width left) gap))))
        (setq right (if (zerop room)
                        ""
                      (truncate-string-to-width right room nil nil (iys/ui--tray-ellipsis))))))
    (when (> (string-width left) (1- width))
      (setq left (truncate-string-to-width left (1- width) nil nil (iys/ui--tray-ellipsis)))
      (setq right ""))
    (iys/ui--tray-line left right)))

(defvar iys/ui--tray-resize-saved nil)
(defvar iys/ui--tray-resize-locked nil)

(defun iys/ui--tray-pad ()
  "和 tab-line 用同一套上下内边距。上边距在分割线里，下边距是 line-spacing。
⚠ 文本终端没有像素级内边距：`字高 + 2px' 会被向上取整成两行，回声区永远
是两条高。故终端下返回 0，托盘退化成一行。"
  (if (display-graphic-p)
      (if (boundp 'iys/ui-bar-padding) iys/ui-bar-padding 2)
    0))

(defun iys/ui--tray-target-height ()
  "状态文字这一行的像素高度：字高 + 下边距。
加上分割线里的上边距之后，和 tab-line（字高 + 上下边距）一样高。亮线本身不算在内。"
  (+ (default-font-height) (iys/ui--tray-pad)))

(defun iys/ui--tray-lock-resize ()
  "提示消息不要改 minibuffer 高度，否则 :w 时这一行会跳。"
  (unless iys/ui--tray-resize-locked
    (setq iys/ui--tray-resize-saved resize-mini-windows
          iys/ui--tray-resize-locked t))
  (setq resize-mini-windows nil))

(defun iys/ui--tray-unlock-resize ()
  (when iys/ui--tray-resize-locked
    (setq resize-mini-windows iys/ui--tray-resize-saved
          iys/ui--tray-resize-locked nil)))

(defun iys/ui--tray-fit-height ()
  "把空闲 minibuffer 固定到 `iys/ui--tray-target-height'。
正在显示提示或正在输入时不动，避免和回显抢高度。
`window-resize' 默认把像素收成整行，这里临时打开 `window-resize-pixelwise'。
⚠ 只在图形终端做：文本终端按整行取整，`字高 + pad' 会多撑出一行。"
  (when (and iys/ui-echo-tray-mode
             (not (active-minibuffer-window))
             (not (current-message)))
    (let ((win (minibuffer-window)))
      (when (and (window-live-p win)
                 (display-graphic-p (window-frame win)))
        (let ((delta (- (iys/ui--tray-target-height)
                        (window-pixel-height win))))
          (unless (zerop delta)
            (condition-case nil
                (let ((window-resize-pixelwise t))
                  (window-resize win delta nil nil t))
              (error nil))))))))

(defun iys/ui--echo-tray-suppressed-p ()
  (or (active-minibuffer-window)
      (bound-and-true-p isearch-mode)))

;; ---- echo 消息并入托盘行 -------------------------------------------------
;; `set-message-functions' 里的函数返回 t = 别再单独显示这条消息（返回值不是
;; 字符串时，C 那边就不再往 echo area 写）。默认那条 `set-minibuffer-message'
;; 仍然排在后面，处理“正在输入 minibuffer”时的消息。
(defun iys/ui--tray-message-clear ()
  "忘掉接管的 echo 消息，并取消到期定时器。"
  (when (timerp iys/ui--tray-message-timer)
    (cancel-timer iys/ui--tray-message-timer))
  (setq iys/ui--tray-message-timer nil
        iys/ui--tray-message nil))

(defun iys/ui--tray-message-expire ()
  (setq iys/ui--tray-message-timer nil)
  (when iys/ui--tray-message
    (setq iys/ui--tray-message nil)
    (iys/ui--echo-tray-update)))

(defun iys/ui--tray-message-handler (msg)
  "把 echo 消息并进托盘行；返回 t 表示不用 echo area 单独显示。
正在用 minibuffer / isearch 时返回 nil，交回默认处理——那种时候消息得显示
在输入行上，塞进托盘反而看不见。"
  (cond
   ((not (stringp msg)) nil)
   ;; (message "") 是“清掉回显”，顺手把托盘里的旧消息一起清掉
   ((string-empty-p msg)
    (iys/ui--tray-message-clear)
    nil)
   ((or (not iys/ui-echo-tray-mode)
        (iys/ui--echo-tray-suppressed-p))
    nil)
   (t
    (setq iys/ui--tray-message msg)
    (when (timerp iys/ui--tray-message-timer)
      (cancel-timer iys/ui--tray-message-timer))
    (setq iys/ui--tray-message-timer
          (run-at-time iys/ui--tray-message-duration nil
                       #'iys/ui--tray-message-expire))
    ;; echo area 里可能还挂着上一条（isearch/输入中漏过去的），不清会盖住托盘
    (when (current-message) (message nil))
    (iys/ui--echo-tray-update)
    t)))

(defun iys/ui--tray-bar-bg ()
  "和 tab-line 那条 bar 同一个背景，上下 padding 才是同一块颜色。"
  (let ((c (cond
            ((fboundp 'iys/ui--bg-of) (iys/ui--bg-of 'tab-line))
            ((facep 'tab-line) (ignore-errors (face-background 'tab-line nil t))))))
    (and (stringp c) (not (string-prefix-p "unspecified" c)) c)))

(defun iys/ui--tray-style-buffer (buf)
  "底色、下边距跟 tab-line 对齐。只改托盘和回显用的 buffer，不影响正在输入的 minibuffer。"
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq-local cursor-type nil)
      (setq-local mode-line-format nil)
      (setq-local line-spacing (iys/ui--tray-pad))
      (when-let* ((bg (iys/ui--tray-bar-bg)))
        (setq-local face-remapping-alist `((default (:background ,bg))))))))

(defun iys/ui--tray-set-minibuf (text)
  "把 TEXT 写进空闲 minibuffer。这个 buffer 空着时，底部那一行不会出现。"
  (let ((buf (get-buffer-create " *Minibuf-0*")))
    (iys/ui--tray-style-buffer buf)
    (dolist (name '(" *Echo Area 0*" " *Echo Area 1*"))
      (iys/ui--tray-style-buffer (get-buffer-create name)))
    (with-current-buffer buf
      (buffer-disable-undo)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (when (and text (not (string-empty-p text)))
          (insert text))
        (goto-char (point-min))))))

(defun iys/ui--sync-mode-line ()
  "托盘开着时不显示 mode-line。关掉后，原来那几类 buffer 恢复自定义 mode-line。"
  (setq mode-line-format
        (cond
         ((minibufferp) nil)
         ((and (not iys/ui-echo-tray-mode)
               (derived-mode-p 'prog-mode 'text-mode 'conf-mode 'dired-mode))
          iys/ui-mode-line-format)
         (t nil))))

(defun iys/ui--sync-all-mode-lines ()
  (setq-default mode-line-format nil)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (iys/ui--sync-mode-line))))

(defun iys/ui--echo-tray-update ()
  (unless (or iys/ui--tray-updating (iys/ui--echo-tray-suppressed-p))
    (let ((iys/ui--tray-updating t))
      (let* ((win (or (minibuffer-selected-window) (selected-window)))
             (text (if (window-live-p win)
                       (with-current-buffer (window-buffer win)
                         (iys/ui--tray-render))
                     "")))
        (iys/ui--tray-set-minibuf text)
        (iys/ui--tray-fit-height)))))

(defun iys/ui--tray-on-minibuffer-setup ()
  (setq resize-mini-windows 'grow-only))

(defun iys/ui--tray-on-minibuffer-exit ()
  (when iys/ui--tray-resize-locked
    (setq resize-mini-windows nil))
  (iys/ui--tray-fit-height))

(defun iys/ui--echo-tray-enable ()
  (iys/ui--sync-all-mode-lines)
  (iys/ui--tray-lock-resize)
  (add-hook 'after-change-major-mode-hook #'iys/ui--sync-mode-line)
  (add-hook 'post-command-hook #'iys/ui--echo-tray-update)
  (add-hook 'echo-area-clear-hook #'iys/ui--echo-tray-update)
  (add-hook 'minibuffer-setup-hook #'iys/ui--tray-on-minibuffer-setup)
  (add-hook 'minibuffer-exit-hook #'iys/ui--tray-on-minibuffer-exit)
  ;; 排在 `set-minibuffer-message' 前面：托盘优先接管，输入中让它接手
  (add-to-list 'set-message-functions #'iys/ui--tray-message-handler)
  (unless iys/ui--tray-timer
    (setq iys/ui--tray-timer (run-with-timer 1 1 #'iys/ui--echo-tray-update)))
  (when (fboundp 'iys/ui-setup-bars)
    (iys/ui-setup-bars))
  (when (fboundp 'iys/update-bottom-divider)
    (iys/update-bottom-divider))
  (iys/ui--echo-tray-update))

(defun iys/ui--echo-tray-disable ()
  (when iys/ui--tray-timer
    (cancel-timer iys/ui--tray-timer)
    (setq iys/ui--tray-timer nil))
  (setq set-message-functions (delq #'iys/ui--tray-message-handler
                                    set-message-functions))
  (iys/ui--tray-message-clear)
  (remove-hook 'post-command-hook #'iys/ui--echo-tray-update)
  (remove-hook 'echo-area-clear-hook #'iys/ui--echo-tray-update)
  (remove-hook 'after-change-major-mode-hook #'iys/ui--sync-mode-line)
  (remove-hook 'minibuffer-setup-hook #'iys/ui--tray-on-minibuffer-setup)
  (remove-hook 'minibuffer-exit-hook #'iys/ui--tray-on-minibuffer-exit)
  (iys/ui--tray-set-minibuf "")
  (iys/ui--tray-unlock-resize)
  (iys/ui--sync-all-mode-lines)
  (when (fboundp 'iys/update-bottom-divider)
    (iys/update-bottom-divider))
  (when (fboundp 'iys/ui-setup-bars)
    (iys/ui-setup-bars)))

(define-minor-mode iys/ui-echo-tray-mode
  "把原 mode-line 显示在 minibuffer 这一行：左段靠左，右段靠右。
echo 消息不单独占一行，而是接在左段状态后面显示
`iys/ui--tray-message-duration' 秒；右段的项目/分支可以直接点。
正在输入或 isearch 时先让出这一行。"
  :global t
  :group 'mode-line
  (if iys/ui-echo-tray-mode
      (iys/ui--echo-tray-enable)
    (iys/ui--echo-tray-disable)))

(unless noninteractive
  (iys/ui-echo-tray-mode 1))

(provide 'init-mode-line)
