;;; iys-notify.el --- posframe 通知：echo 与交互 eldoc 共用弹出  -*- lexical-binding: t -*-

;; Author: iysun
;; Package-Requires: ((emacs "29.1"))
;; Keywords: frames, convenience

;; echo 消息和交互式 `eldoc' 走同一个 posframe。idle eldoc 默认吞掉。
;; Emacs 31 的 TTY child frame 也能弹；posframe 不可用时退回默认。
;; 不自动启用，开 `iys-notify-mode'。

;;; Code:

(require 'eldoc)

(defgroup iys-notify nil
  "用 posframe 弹出 echo 消息和交互式文档。"
  :group 'convenience
  :prefix "iys-notify-")

(defcustom iys-notify-padding 8
  "通知相对父 frame 边缘的像素边距。"
  :type 'integer
  :group 'iys-notify)

(defcustom iys-notify-echo-max-height 8
  "echo 通知最大行数。"
  :type 'integer
  :group 'iys-notify)

(defcustom iys-notify-doc-max-height 20
  "文档通知最大行数。"
  :type 'integer
  :group 'iys-notify)

(defcustom iys-notify-echo-max-width 72
  "echo 通知最大列数（再和 frame 宽度取小）。"
  :type 'integer
  :group 'iys-notify)

(defcustom iys-notify-doc-max-width 90
  "文档通知最大列数（再和 frame 宽度取小）。"
  :type 'integer
  :group 'iys-notify)

(defcustom iys-notify-min-width 24
  "通知最小列数。"
  :type 'integer
  :group 'iys-notify)

(defcustom iys-notify-swallow-idle-eldoc t
  "非 nil 时吞掉 idle eldoc 的 echo（只留交互式 `iys-notify-doc-at-point' 弹文档）。"
  :type 'boolean
  :group 'iys-notify)

(defcustom iys-notify-persist-commands
  '(iys-notify-doc-at-point iys-notify-hide iys-notify-pop-out
    iys/doc-at-point)
  "这些命令不关掉当前通知（`pre-command-hook' 里跳过）。"
  :type '(repeat function)
  :group 'iys-notify)

(defcustom iys-notify-inhibit-functions
  '(iys-notify--inhibit-minibuffer
    iys-notify--inhibit-isearch
    iys-notify--inhibit-which-key)
  "任一返回非 nil 则这条 echo 交回默认 echo area。函数收到消息字符串。"
  :type 'hook
  :group 'iys-notify)

(defcustom iys-notify-poshandler #'iys-notify-poshandler-bottom-right
  "posframe 位置函数，签名同 `posframe-show' 的 :poshandler。"
  :type 'function
  :group 'iys-notify)

(defface iys-notify
  '((t :inherit default))
  "通知子 frame 的前景/背景。默认跟正文同一底，靠边框把面板勾出来。"
  :group 'iys-notify)

(defface iys-notify-border
  '((t :inherit vertical-border))
  "通知子 frame 的边框色。"
  :group 'iys-notify)

(defvar iys-notify--kind nil)
(defvar iys-notify--buffer nil)
(defconst iys-notify--echo-buffer " *iys-notify*")

(defun iys-notify--workable-p ()
  (and (require 'posframe nil t)
       (fboundp 'posframe-workable-p)
       (posframe-workable-p)))

(defun iys-notify--face-attr (face attr fallback)
  (let ((v (face-attribute face attr nil t)))
    (if (or (null v) (eq v 'unspecified)) fallback v)))

(defun iys-notify--inhibit-minibuffer (_msg)
  (active-minibuffer-window))

(defun iys-notify--inhibit-isearch (_msg)
  (bound-and-true-p isearch-mode))

(defun iys-notify--inhibit-which-key (_msg)
  (and (fboundp 'which-key--popup-showing-p)
       (which-key--popup-showing-p)))

;;;###autoload
(defun iys-notify-poshandler-bottom-right (info)
  "贴在 frame 右下，抬到 minibuffer 上面。"
  (let* ((pad iys-notify-padding)
         (mh (or (plist-get info :minibuffer-height) 0))
         (x (- (plist-get info :parent-frame-width)
               (plist-get info :posframe-width)
               pad))
         (y (- (plist-get info :parent-frame-height)
               (plist-get info :posframe-height)
               mh
               pad)))
    (cons (max pad x) (max pad y))))

(defun iys-notify-visible-p ()
  "子 frame 是否正显示。"
  (when-let* ((buf iys-notify--buffer)
              ((buffer-live-p buf))
              ((iys-notify--workable-p)))
    (let ((fr (buffer-local-value 'posframe--frame buf)))
      (and (frame-live-p fr) (frame-visible-p fr)))))

;;;###autoload
(defun iys-notify-hide ()
  "关掉通知子 frame。"
  (interactive)
  (when (and iys-notify--buffer (fboundp 'posframe-hide))
    (posframe-hide iys-notify--buffer))
  (setq iys-notify--kind nil
        iys-notify--buffer nil))

(defun iys-notify--show (buffer kind &optional string)
  (when (iys-notify--workable-p)
    (setq iys-notify--kind kind
          iys-notify--buffer buffer)
    (let* ((doc (eq kind 'doc))
           (bg (iys-notify--face-attr 'iys-notify :background
                                      (face-background 'default nil t)))
           (fg (iys-notify--face-attr 'iys-notify :foreground
                                      (face-foreground 'default nil t)))
           (border (iys-notify--face-attr 'iys-notify-border :foreground fg))
           (cap (if doc iys-notify-doc-max-width iys-notify-echo-max-width))
           (max-w (max 40 (min cap (/ (* (frame-width) 2) 5))))
           (max-h (if doc iys-notify-doc-max-height iys-notify-echo-max-height))
           (fringe (if (display-graphic-p) 8 0)))
      (posframe-show
       buffer
       :string string
       :poshandler iys-notify-poshandler
       :internal-border-width 1
       :internal-border-color border
       :background-color bg
       :foreground-color fg
       :left-fringe fringe
       :right-fringe fringe
       :max-width max-w
       :max-height max-h
       :min-width (min iys-notify-min-width max-w)
       :accept-focus nil
       :override-parameters '((cursor-type . nil)
                              (no-accept-focus . t)))
      t)))

;;;###autoload
(defun iys-notify-show (text)
  "把 TEXT 弹成 echo 通知。下一条命令关掉；`read-event' 期间会留着。"
  (when (and (stringp text)
             (not (string-empty-p (substring-no-properties text))))
    (iys-notify--show (get-buffer-create iys-notify--echo-buffer) 'echo text)))

(defun iys-notify--eldoc-display (docs interactive)
  "交互式 `eldoc' 弹通知。idle 不管。
`interactive' 由 `eldoc--invoke-strategy' 闭包带着，eglot hover 异步回来仍是 t。"
  (when (and interactive docs (iys-notify--workable-p))
    (eldoc--format-doc-buffer docs)
    (iys-notify--show eldoc--doc-buffer 'doc)))

(defun iys-notify--eldoc-in-buffer (orig docs interactive)
  "已经弹了通知，别再拆一个 *eldoc* 窗口。"
  (if (and interactive (iys-notify--workable-p))
      (progn (eldoc--format-doc-buffer docs) nil)
    (funcall orig docs interactive)))

;;;###autoload
(defun iys-notify-pop-out ()
  "把当前通知落到普通窗口，便于翻页/选区复制。"
  (interactive)
  (unless (buffer-live-p iys-notify--buffer)
    (user-error "没有通知"))
  (let ((buf iys-notify--buffer))
    (iys-notify-hide)
    (with-current-buffer buf
      (when (string-prefix-p " " (buffer-name))
        (rename-buffer (string-trim-left (buffer-name)) t))
      (unless (derived-mode-p 'special-mode)
        (special-mode)))
    (pop-to-buffer buf)))

;;;###autoload
(defun iys-notify-doc-at-point ()
  "看光标处符号的文档。通知已在就落到普通窗口（echo / 文档都行）。

走交互 `eldoc'，绕过 idle delay，eglot 的 hover 是异步的，等结果回来才画。"
  (interactive)
  (if (buffer-live-p iys-notify--buffer)
      (iys-notify-pop-out)
    (call-interactively #'eldoc)))

(defun iys-notify--message-handler (msg)
  "echo 消息改走通知。返回 t 则不再写 echo area。"
  (cond
   ((not (iys-notify--workable-p)) nil)
   ((not (stringp msg)) nil)
   ((eq iys-notify--kind 'doc) t)
   ((string-empty-p (substring-no-properties msg))
    (when (eq iys-notify--kind 'echo) (iys-notify-hide))
    nil)
   ((run-hook-with-args-until-success 'iys-notify-inhibit-functions msg)
    nil)
   ;; eldoc 在调用 `message' 之前写入的是 `eldoc-last-message'，没有双横线那份。
   ((and iys-notify-swallow-idle-eldoc
         (stringp eldoc-last-message)
         (string= (substring-no-properties msg)
                  (substring-no-properties eldoc-last-message)))
    t)
   (t (and (iys-notify-show msg) t))))

(defun iys-notify--keep-p (cmd)
  "CMD 及其 alias 目标都算。`gh' 绑的是 `iys/doc-at-point'，不能只认 `iys-notify-*'。"
  (let* ((fn (and (symbolp cmd) (fboundp cmd) (indirect-function cmd)))
         (name (and (symbolp cmd) (symbol-name cmd))))
    (or (memq cmd iys-notify-persist-commands)
        (and fn (memq fn iys-notify-persist-commands))
        (and name (or (string-prefix-p "iys-notify-" name)
                      (string= name "iys/doc-at-point")))
        (eq fn (indirect-function 'iys-notify-doc-at-point))
        (eq fn (indirect-function 'iys-notify-pop-out)))))

(defun iys-notify--on-pre-command ()
  (unless (iys-notify--keep-p this-command)
    (iys-notify-hide)))

(defun iys-notify--enable ()
  (add-hook 'pre-command-hook #'iys-notify--on-pre-command)
  (add-hook 'eldoc-display-functions #'iys-notify--eldoc-display)
  (add-to-list 'set-message-functions #'iys-notify--message-handler)
  (advice-add 'eldoc-display-in-buffer :around #'iys-notify--eldoc-in-buffer))

(defun iys-notify--disable ()
  (setq set-message-functions (delq #'iys-notify--message-handler
                                    set-message-functions))
  (remove-hook 'pre-command-hook #'iys-notify--on-pre-command)
  (remove-hook 'eldoc-display-functions #'iys-notify--eldoc-display)
  (advice-remove 'eldoc-display-in-buffer #'iys-notify--eldoc-in-buffer)
  (iys-notify-hide))

;;;###autoload
(define-minor-mode iys-notify-mode
  "用 posframe 弹出 echo 消息和交互式 eldoc。

echo 到下一条命令关掉（`read-event' 期间会留着）。
`iys-notify-doc-at-point' 第一次弹文档；通知已在则落到普通窗口。"
  :global t
  :group 'iys-notify
  :lighter nil
  (if iys-notify-mode
      (iys-notify--enable)
    (iys-notify--disable)))

(provide 'iys-notify)

;;; iys-notify.el ends here
