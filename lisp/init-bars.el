;; init-bars.el 	-*- lexical-binding: t -*-
;;
;; 两条「bar」：底部 mode-line 与顶部 tab-line。
;; 从 init-ui.el / init-window.el 抽出来单独成模块——这两者要在字号、内边距上
;; 保持一致（见文件末尾的 `my-ui-setup-bars'），放在一起改才不会顾此失彼。
;;
;; 结构：
;;   1. mode-line —— 分段、图标、缓存、可点击（结构照抄 zdn/.emacs.d 的 nn-mode-line）
;;   2. tab-line  —— 按项目分组 + 过滤 eglot buffer（原生 tab-line，替代 centaur-tabs）
;;   3. 两条 bar 的尺寸 —— 字号与上下 padding 统一设置

;; ================= mode-line =================
;; ---- mode-line（结构照抄 zdn/.emacs.d 的 nn-mode-line，替代 doom-modeline）----
;;
;; 布局：evil态 |  分支 | 文件名 | 诊断 | LSP ——右对齐—— L C | 编码 | LF | 中/A | major-mode
;;
;; 和 zdn 的两处**有意不同**（照抄会是功能倒退，见各处注释）：
;;   1. 保留 evil 状态段——zdn 不用 evil。
;;   2. 用 `setq-default' 兜底，而不是只在几个 mode-hook 里 `setq-local'。
;; 尺寸取它的观感（细窄状态条、无 box），但用**相对字号**而非它写死的绝对磅值，
;; 以免换机器/换 DPI 走形。见文件末尾 `my-ui-setup-bars'。
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
            `((git     . ,(nerd-icons-powerline "nf-pl-branch"))
              (error   . ,(nerd-icons-codicon "nf-cod-error"))
              (warning . ,(nerd-icons-codicon "nf-cod-warning"))
              (info    . ,(nerd-icons-codicon "nf-cod-info")))))))
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
  "分支名（带图标）。点击开 magit，没有则退回 vc-dir。"
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
               "mouse-1: magit-status"
               (lambda () (interactive)
                 (if (fboundp 'magit-status)
                     (magit-status)
                   (vc-dir default-directory))))))))

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
  "major mode 名。点击可切换到别的 major mode（照抄 zdn 的行为）。"
  (my-ui--ml-click
   (string-trim-right (symbol-name major-mode) "-mode\\'")
   "mouse-1: 切换 major mode"
   (lambda () (interactive)
     (let* ((name (completing-read "语言: " (my-ui--ml-prog-modes) nil t))
            (mode (intern (concat name "-mode"))))
       (when (commandp mode) (funcall mode))))))

(defun my-ui-ml-input-method ()
  "输入法指示。
⚠ 本仓库的中英切换走的是外部 `im-select.exe'（见 init-evil.el），
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

;; zdn 只在这几个 mode-hook 里 setq-local，其余缓冲区（magit/eshell/help/*scratch*…）
;; 保持 early-init 设的 nil，即**完全没有 mode-line**——那是它刻意的极简取向。
;; 本仓库改为同时 setq-default 兜底：观感在 prog/text/conf/dired 下与 zdn 一致，
;; 但 magit / eshell / popper 弹窗等仍有 mode-line（那些地方正需要上下文）。
;; 想要 zdn 那种「其余一律无 mode-line」，把下面这行 setq-default 删掉即可。
(setq-default mode-line-format my-ui-mode-line-format)

;; 进这些 mode 时清一次缓存：同一个 buffer 换了文件/换了 mode，分支和诊断都可能变。
(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook dired-mode-hook))
  (add-hook hook (lambda ()
                   (setq my-ui--ml-vc-cache nil
                         my-ui--ml-eglot-cache nil
                         my-ui--ml-flymake-cache nil)
                   (setq-local mode-line-format my-ui-mode-line-format))))

;; mode-line / tab-line 的尺寸。主题加载会重置这些 face，
;; 故挂到 enable-theme-functions（每次启用主题后重新应用）+ after-init 兜底。
;;

;; ================= tab-line =================
;; 原生 tab-line（按项目分组 + 过滤 eglot buffer）——替代 centaur-tabs，零第三方、零启动开销。
(defun my/tab-line-buffer-group-by-project (&optional buffer)
  "Group buffers by project root via project.el."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((dir (or (buffer-file-name) nil))
           (proj (project-current nil dir))
           (root (when proj (project-root proj))))
      (if (and root dir)
          (file-name-nondirectory (directory-file-name root))
        "Other"))))

(defun my/tab-line-filter (buffers)
  "Filter out Eglot-generated buffers from tab-line."
  (let (result)
    (dolist (buf buffers (nreverse result))
      (let ((name (buffer-name buf)))
        (unless (and name
                     (let ((case-fold-search t))
                       (string-match-p "\\`\\s-*\\*eglot" name)))
          (push buf result))))))

(progn
  (setq tab-line-tabs-function 'tab-line-tabs-buffer-groups)
  (setq tab-line-tabs-buffer-group-function #'my/tab-line-buffer-group-by-project)
  (advice-add 'tab-line-tabs-buffer-list :filter-return #'my/tab-line-filter))

(add-hook 'after-init-hook 'global-tab-line-mode)

;; ================= 两条 bar 的尺寸 =================
;; 上下两条 bar（顶部 tab-line、底部 mode-line）做成**一对**：
;;   - 字号都跟正文一样（不缩小）
;;   - 上下内边距都取同一个值，厚度一致
;; 之前照抄 zdn 把 mode-line 设成 0.87 且去掉 box，结果字偏小、且与仍带 padding
;; 的 tab-line 一薄一厚，两条不像一套——就是这个问题。
;;
;; padding 用 box 实现，颜色取各自背景色 → 呈现为内边距而不是可见边框。
;; 线宽 cons 语义：(左右 . 上下)。
;;
;; 想再回到 zdn 那种细窄状态条：把 `my-ui-mode-line-height' 改成 0.87、
;; `my-ui-bar-padding' 改成 0（mode-line 会退化成无 box 的一条细线）。
;;
;; 注：zdn 是挂在 `after-make-frame-functions' 上的，那个钩子**对初始 frame 不触发**，
;; 所以它的字号实际只对后开的 frame 生效。这里沿用本仓库的 after-init +
;; enable-theme-functions，初始 frame 也能正确应用。
(defconst my-ui-mode-line-height 1.0
  "mode-line / tab-line 字号，相对 default face 的**倍数**。
1.0 = 与正文等大。必须是浮点数才是相对值；写成整数会变成绝对磅值，
在不同 DPI 的机器上会走形。")

(defconst my-ui-bar-padding 2
  "两条 bar 的上下内边距（像素）。mode-line 与 tab-line 用同一个值，厚度才一致。
设 0 则不加 box，退化成最细的一条线。")

(defconst my-ui-tab-side-padding 8
  "tab-line 每个标签的左右内边距（像素），让标签之间松一些。")

(defun my-ui--real-color (c)
  "C 是真实颜色名就返回它，否则 nil。
`face-background' 在没有实际背景时会返回伪值 \"unspecified-bg\"，
拿它当 box 颜色会渲染成**可见边框**而非内边距，正是要避免的。"
  (and (stringp c)
       (not (member c '("unspecified-bg" "unspecified-fg")))
       c))

(defun my-ui--bg-of (face)
  "取 FACE 背景色（含继承）；取不到则回退 default 背景，再不行用兜底色。"
  (or (my-ui--real-color (face-background face nil t))
      (my-ui--real-color (face-background 'default nil t))
      "#1e1e1e"))

(defun my-ui--bar-box (face)
  "给 FACE 生成「只当内边距、不显边框」的 box 规格；padding 为 0 时返回 nil。"
  (if (> my-ui-bar-padding 0)
      `(:line-width (1 . ,my-ui-bar-padding) :color ,(my-ui--bg-of face))
    nil))

(defun my-ui-setup-bars (&rest _)
  "把 mode-line 与 tab-line 调成字号一致、厚度一致的一对。"
  (require 'tab-line nil t)                       ; 确保 tab-line-* face 已定义
  ;; mode-line：字号与正文一致 + 与 tab-line 相同的上下 padding。
  ;; mode-line-active 是 Emacs 29+ 才有的 face，故用 facep 逐个判断。
  (dolist (f '(mode-line mode-line-active mode-line-inactive))
    (when (facep f)
      (set-face-attribute f nil :height my-ui-mode-line-height
                          :box (my-ui--bar-box f))))
  ;; tab-line 整条：同字号、同上下 padding。
  ;; tab-line-active / tab-line-inactive 是 Emacs 31 新增（选中窗口用 active，其余用
  ;; inactive），目前定义为纯继承 `((t :inherit tab-line))'，所以只设 tab-line 也生效；
  ;; 但主题一旦给它们设了显式属性，继承链就断了，两条 bar 会厚度不一致。
  ;; 与上面 mode-line 一样用 facep 逐个判断，把新 face 一起兜住。
  (dolist (f '(tab-line tab-line-active tab-line-inactive))
    (when (facep f)
      (set-face-attribute f nil :height my-ui-mode-line-height
                          :box (my-ui--bar-box f))))
  ;; 每个标签：左右加宽让标签之间松一些，上下用与整条 bar 相同的 padding，
  ;; 否则标签会比它所在的 bar 更高/更矮，边缘出现台阶。
  (dolist (f '(tab-line-tab tab-line-tab-current tab-line-tab-inactive))
    (when (facep f)
      (set-face-attribute
       f nil :height my-ui-mode-line-height
       :box `(:line-width (,my-ui-tab-side-padding . ,my-ui-bar-padding)
              :color ,(my-ui--bg-of f))))))

(add-hook 'after-init-hook #'my-ui-setup-bars t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-ui-setup-bars))

(provide 'init-bars)
