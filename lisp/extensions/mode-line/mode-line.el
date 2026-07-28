;; extensions/mode-line/mode-line.el 	-*- lexical-binding: t -*-
;;
;; mode-line 实现本体，由 `lisp/init-bars.el' `load'。结构照抄 zdn/.emacs.d 的
;; nn-mode-line，替代 doom-modeline。两条 bar（mode-line + tab-line）的共享工具函数
;; （`my-ui--glyph-displayable-p' 等）和字号/内边距统一逻辑留在 `init-bars.el' 里，
;; 这个文件只管 mode-line 本身的分段/图标/缓存/可点击。
;;
;; 布局：evil态 |  分支 | 文件名 | 诊断 | LSP ——右对齐—— L C | 编码 | LF | 中/A | major-mode
;;
;; 和 zdn 的两处**有意不同**（照抄会是功能倒退，见各处注释）：
;;   1. 保留 evil 状态段——zdn 不用 evil。
;;   2. 图标改惰性缓存（`after-init-hook' 里取一次、取不到就退回纯文本），而不是
;;      zdn 那种加载期直接 `defconst' 调 `nerd-icons-*'——那要求 nerd-icons 那一刻
;;      已经加载完，本仓库 nerd-icons 是 `:defer t'，字面照抄会在启动时直接报
;;      `void-function'。两种写法用户看到的最终效果一样，只是本仓库这种不用把
;;      nerd-icons 从"按需加载"改回"启动就加载"。
;; 其余（mode-line 可见范围、VC 段点击动作、major-mode 段显示条件）都已对齐 zdn。
;; 尺寸取它的观感（细窄状态条、无 box），但用**相对字号**而非它写死的绝对磅值，
;; 以免换机器/换 DPI 走形。见 `init-bars.el' 里的 `my-ui-setup-bars'。
;;
;; 设计要点：贵的段（分支、诊断、LSP）算一次就缓存到 buffer-local，
;; 靠 advice 在状态真的变了时失效。mode-line 每次 redisplay 都要求值，
;; 像 `vc-call-backend' 这种调用绝不能每帧跑。

;; 换行符助记符。默认是 `(Unix)'/`(DOS)' 这类，占地方又不直观。
(setq eol-mnemonic-unix "LF"
      eol-mnemonic-dos  "CRLF"
      eol-mnemonic-mac  "CR"
      eol-mnemonic-undecided "?")

;; ---- 图标 ----
;; zdn 用 defconst 在加载期调 `nerd-icons-*'，那要求 nerd-icons 已加载。
;; 这里改成 after-init 缓存一次 + 取不到就回退纯文本，避免顺序依赖。
(defvar my-ui--ml-icons nil
  "mode-line 图标缓存，形如 ((git . \"\") (error . ...) ...)。")

(defun my-ui--ml-icon (key fallback)
  (or (alist-get key my-ui--ml-icons) fallback))

(defun my-ui--ml-init-icons ()
  (when (and (display-graphic-p) (require 'nerd-icons nil t))
    (setq my-ui--ml-icons
          (ignore-errors
            (seq-filter
             (lambda (cell) (my-ui--glyph-displayable-p (cdr cell)))
             `((git     . ,(nerd-icons-powerline "nf-pl-branch"))
               (error   . ,(nerd-icons-codicon "nf-cod-error"))
               (warning . ,(nerd-icons-codicon "nf-cod-warning"))
               (info    . ,(nerd-icons-codicon "nf-cod-info"))))))))
(add-hook 'after-init-hook #'my-ui--ml-init-icons)

;; ---- 可点击段 ----
(defun my-ui--ml-click (text help cmd)
  "把 TEXT 包成可点击段：悬浮显示 HELP，鼠标左键执行 CMD。"
  (propertize text
              'mouse-face 'mode-line-highlight
              'help-echo help
              'local-map (let ((m (make-sparse-keymap)))
                           (define-key m [mode-line mouse-1] cmd)
                           m)))

;; ---- 缓存 ----
(defvar my-ui--ml-prog-modes-cache nil)
(defvar-local my-ui--ml-vc-cache nil)
(defvar-local my-ui--ml-eglot-cache nil)
(defvar-local my-ui--ml-flymake-cache nil)
(defvar-local my-ui--ml-flymake-counts '(0 0 0))

;; ---- 各段 ----
(defun my-ui-ml-vc ()
  "分支名（带图标）。点击开 vc-dir。"
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
               (concat (my-ui--ml-icon 'git "") " " (substring-no-properties branch))
               "mouse-1: vc-dir"
               #'vc-dir)))))

(defun my-ui-ml-flymake ()
  "诊断计数（错误/警告/提示），带图标。点击列出本缓冲区诊断。"
  (when (bound-and-true-p flymake-mode)
    (or my-ui--ml-flymake-cache
        (setq my-ui--ml-flymake-cache
              (my-ui--ml-click
               (format "%s %d  %s %d  %s %d"
                       (my-ui--ml-icon 'error "E")   (nth 0 my-ui--ml-flymake-counts)
                       (my-ui--ml-icon 'warning "W") (nth 1 my-ui--ml-flymake-counts)
                       (my-ui--ml-icon 'info "I")    (nth 2 my-ui--ml-flymake-counts))
               "mouse-1: 列出本缓冲区诊断"
               #'flymake-show-buffer-diagnostics)))))

(defun my-ui-ml-eglot ()
  "LSP 服务名与状态。点击打开该 server 的 stderr 缓冲区。
用了 eglot 内部符号（`eglot--managed-mode' 等），故整体包 ignore-errors——
上游改名时最多这段不显示，不会把整条 mode-line 带崩。"
  (when (bound-and-true-p eglot--managed-mode)
    (or my-ui--ml-eglot-cache
        (setq my-ui--ml-eglot-cache
              (ignore-errors
                (let* ((prog (alist-get major-mode eglot-server-programs))
                       (name (cond ((stringp prog) prog)
                                   ((consp prog) (format "%s" (car prog)))
                                   (t "lsp")))
                       (proc (ignore-errors (jsonrpc--process (eglot-current-server))))
                       (state (pcase (if proc (process-status proc) 'starting)
                                ('run "idle") ('exit "stopped") ('signal "crashed")
                                ('connect "connecting") ('listen "starting")
                                (s (format "%s" s)))))
                  (my-ui--ml-click
                   (format "%s: %s" name state)
                   "mouse-1: LSP 日志"
                   (lambda () (interactive)
                     (if-let* ((s (eglot-current-server))
                               (buf (eglot--stderr-buffer s)))
                         (switch-to-buffer-other-window buf)
                       (message "没有正在运行的 LSP server"))))))))))

(defun my-ui-ml-position ()
  "行列号。点击可跳到指定 行:列。"
  (when buffer-file-name
    (my-ui--ml-click
     (format "L%s C%s" (format-mode-line "%l") (format-mode-line "%c"))
     "mouse-1: 跳到 行:列"
     (lambda () (interactive)
       (let ((input (read-string "跳到 行:列（如 42:10）: ")))
         (when (string-match "\\`\\([0-9]+\\)\\(?::\\([0-9]+\\)\\)?\\'" input)
           (goto-char (point-min))
           (forward-line (1- (string-to-number (match-string 1 input))))
           (when (match-string 2 input)
             (move-to-column (string-to-number (match-string 2 input))))))))))

(defun my-ui-ml-encoding ()
  "文件编码。点击可改存盘编码，或用指定编码重新打开。"
  (when buffer-file-name
    (my-ui--ml-click
     (symbol-name buffer-file-coding-system)
     "mouse-1: 改编码"
     (lambda () (interactive)
       (let* ((coding (read-coding-system "编码: "))
              (action (completing-read "动作: " '("保存为" "重新打开") nil t)))
         (if (string= action "保存为")
             (progn (set-buffer-file-coding-system coding)
                    (message "将保存为 %s" coding))
           (revert-buffer-with-coding-system coding)))))))

(defun my-ui-ml-eol ()
  "换行符（LF/CRLF/CR）。点击可切换。"
  (when buffer-file-name
    (my-ui--ml-click
     (coding-system-eol-type-mnemonic buffer-file-coding-system)
     "mouse-1: 改换行符"
     (lambda () (interactive)
       (when-let* ((choice (completing-read "换行符: "
                                            '("LF (Unix)" "CRLF (Windows)" "CR (Mac)") nil t))
                   (coding (cdr (assoc choice '(("LF (Unix)"      . utf-8-unix)
                                                ("CRLF (Windows)" . utf-8-dos)
                                                ("CR (Mac)"       . utf-8-mac))))))
         (set-buffer-file-coding-system coding)
         (message "换行符改为 %s" coding))))))

(defun my-ui--ml-prog-modes ()
  "auto-mode-alist 里出现过的 major mode 名（去掉 -mode 后缀），算一次缓存。"
  (or my-ui--ml-prog-modes-cache
      (setq my-ui--ml-prog-modes-cache
            (let ((modes '()))
              (dolist (entry auto-mode-alist)
                (let ((mode (cdr entry)))
                  (when (and (symbolp mode)
                             (not (memq mode modes))
                             (not (memq mode '(fundamental-mode special-mode))))
                    (push mode modes))))
              (sort (mapcar (lambda (m) (string-trim-right (symbol-name m) "-mode\\'")) modes)
                    #'string<)))))

(defun my-ui-ml-major-mode ()
  "major mode 名。点击可切换到别的 major mode（照抄 zdn 的行为）。
只在有文件的 buffer 显示，跟 zdn 一致。"
  (when buffer-file-name
    (my-ui--ml-click
     (string-trim-right (symbol-name major-mode) "-mode\\'")
     "mouse-1: 切换 major mode"
     (lambda () (interactive)
       (let* ((name (completing-read "语言: " (my-ui--ml-prog-modes) nil t))
              (mode (intern (concat name "-mode"))))
         (when (commandp mode) (funcall mode)))))))

(defun my-ui-ml-input-method ()
  "输入法指示。
⚠ 本仓库的中英切换走的是外部 `im-select.exe'（见 lisp/init-ime.el），
不经过 Emacs 的 input method，所以这里**基本恒为 A**。要让它真的反映
Windows IME，得在 `my/switch-to-english-input-method' 那侧自己维护一个变量。
先照抄 zdn 的写法保留位置。"
  (if current-input-method "中" "A"))

;; ---- 缓存失效 ----
(define-advice vc-refresh-state (:after (&rest _) my-ui-reset-vc-cache)
  (setq my-ui--ml-vc-cache nil))

(define-advice flymake--handle-report (:after (&rest _) my-ui-reset-flymake-cache)
  (setq my-ui--ml-flymake-cache nil
        my-ui--ml-flymake-counts
        (list (string-to-number (format-mode-line flymake-mode-line-error-counter))
              (string-to-number (format-mode-line flymake-mode-line-warning-counter))
              (string-to-number (format-mode-line flymake-mode-line-note-counter)))))

(define-advice eglot--managed-mode (:after (&rest _) my-ui-reset-eglot-cache)
  (setq my-ui--ml-eglot-cache nil))

;; ---- 组装 ----
(defconst my-ui-mode-line-format
  '("%e"
    mode-line-front-space
    ;; evil 状态段：zdn 没有这段（它不用 evil），本仓库必须保留。
    (:eval (if (bound-and-true-p evil-local-mode)
               (format "%s " evil-mode-line-tag)
             ""))
    (:eval (my-ui-ml-vc))
    "  "
    "%b"
    "  "
    (:eval (my-ui-ml-flymake))
    "  "
    (:eval (my-ui-ml-eglot))
    "  "
    mode-line-format-right-align
    (:eval (my-ui-ml-position))
    "  "
    (:eval (my-ui-ml-encoding))
    "  "
    (:eval (my-ui-ml-eol))
    "  "
    (:eval (my-ui-ml-input-method))
    "  "
    (:eval (my-ui-ml-major-mode))
    "  "))

;; 跟 zdn 一致：只在下面这几个 mode-hook 里 setq-local，其余缓冲区
;; （magit/eshell/help/*scratch*/popper 弹窗…）保持 early-init.el 设的
;; `(setq-default mode-line-format nil)'，即**完全没有 mode-line**——刻意的极简取向。
;; 想要「其余也都有 mode-line」的兜底，加一行
;; `(setq-default mode-line-format my-ui-mode-line-format)' 即可。

;; 进这些 mode 时清一次缓存：同一个 buffer 换了文件/换了 mode，分支和诊断都可能变。
(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook dired-mode-hook))
  (add-hook hook (lambda ()
                   (setq my-ui--ml-vc-cache nil
                         my-ui--ml-eglot-cache nil
                         my-ui--ml-flymake-cache nil)
                   (setq-local mode-line-format my-ui-mode-line-format))))

(provide 'init-mode-line)
