;; extensions/mode-line/mode-line.el 	-*- lexical-binding: t -*-
;;
;; mode-line 实现本体，由 `lisp/init-bars.el' `load'。基础结构和风格照抄
;; <https://github.com/LionyxML/emacs-solo> 的 `emacs-solo-mode-line.el'
;; （而不是更早那版 zdn/.emacs.d 的 nn-mode-line——那版分段更多、更花，跟
;; emacs-solo 的极简路子不是一回事，已弃用），具体保留哪些段则是问过用户、
;; 逐项确认后精简出来的结果，不是无脑照搬 emacs-solo 全部分段。两条 bar
;; （mode-line + tab-line）的共享工具函数（`my-ui--glyph-displayable-p' 等）
;; 和字号/内边距统一逻辑留在 `init-bars.el' 里，这个文件只管 mode-line 本身
;; 的分段/缓存/可点击。
;;
;; 当前布局：
;;   λ | evil态 | frame-id | 文件名 ——右对齐—— L:C | project | 分支 | flymake 计数 | misc-info
;;
;; 相比 emacs-solo 原版的取舍（用户逐项确认，见各注释）：
;;   - 保留 evil 状态段——emacs-solo 不用 evil，本仓库用，必须保留。
;;   - 去掉 mule-info/client/修改/远程 那一簇（编码/EOL 助记符这类，用户觉得
;;     不好识别、用不上）。
;;   - 去掉 `mode-line-modes'（major mode 名 + 全部 minor-mode-alist），只留其中
;;     flymake 的诊断计数——用内建 `flymake-mode-line-counters' 直接取
;;     "[错误数 警告数]" 那一小块，不用整簇 major/minor mode 名堆过来。
;;     ⚠ 这个变量**不是**没有后端在跑就自动隐藏那么简单：它内部调用
;;     `flymake-running-backends' → `flymake--collect'，后者一上来就
;;     `(unless flymake--state (user-error "Flymake is not initialized"))'。
;;     也就是说只有 flymake-mode **已经打开**的 buffer 上求值它，没后端在跑时
;;     才会安静返回 nil；flymake-mode 根本没开的 buffer（多数非编程 buffer）
;;     上求值会直接抛 user-error，报一屏 "Error during redisplay"。必须自己包
;;     `bound-and-true-p' 判断。
;;   - `mode-line-misc-info' 保留——eglot 等包会自己把状态推到这里
;;     （比如 "[eglot:xxx]"），不用我们自己再写一个 eglot 段。
;;
;; 尺寸取 emacs-solo 的观感（细窄状态条、无 box），但用**相对字号**而非它写死
;; 的绝对磅值，以免换机器/换 DPI 走形。见 `init-bars.el' 里的 `my-ui-setup-bars'。
;;
;; 设计要点：贵的段（project、分支）算一次就缓存到 buffer-local，靠 advice 在
;; 状态真的变了时失效。mode-line 每次 redisplay 都要求值，像 `vc-call-backend'
;; 这种调用绝不能每帧跑。

;; ---- 截断 ----
(defun my-ui--ml-truncate (str &optional limit)
  "STR 超过 LIMIT（默认 20）字符时截断并加省略号。
对应 emacs-solo 的 `emacs-solo/shorten-vc-mode'，避免长分支名/项目名把
mode-line 挤爆。"
  (let ((limit (or limit 20)))
    (if (> (length str) limit)
        (concat (substring str 0 limit) (if (char-displayable-p ?…) "…" "..."))
      str)))

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
(defvar-local my-ui--ml-vc-cache nil)
(defvar-local my-ui--ml-project-cache nil)

;; ---- 各段 ----
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

;; ---- 缓存失效 ----
(define-advice vc-refresh-state (:after (&rest _) my-ui-reset-vc-cache)
  (setq my-ui--ml-vc-cache nil))

;; evil 自己也会在 `mode-line-format' 里找 `mode-line-position' 这个符号、
;; 在旁边插一份 `evil-mode-line-tag'（见 evil-core.el 的
;; `evil-refresh-mode-line'，靠 `setcdr' 直接改 `mode-line-format' 这个列表本身）。
;; zdn/emacs-solo 都不用 evil，原版格式里从没出现过这个符号能匹配，这个自动
;; 插入机制一直是静默禁用的；但本仓库用了内建的 `mode-line-position' 符号，
;; evil 就找到了匹配，于是在我们自己手动加的 evil 段之外又插了一份，肉眼看是
;; "<N>"重复两次。更麻烦的是它用 `setcdr' 直接改列表：`my-ui-mode-line-format'
;; 是 `defconst'，每个 mode-hook 只是 `setq-local' 指向同一个列表对象，evil
;; 一 `setcdr' 就是全局共享结构一起改，不是某个 buffer 局部的事。我们已经自己
;; 手动控制 evil 段的显示位置了，不需要 evil 这份自动插入，直接关掉（nil 是
;; evil 自己文档写明的"不要标签"选项，不是靠副作用关闭）。
(setq evil-mode-line-format nil)

;; ---- 组装 ----
(defconst my-ui-mode-line-format
  '("%e" "  "
    ;; λ 图标：纯装饰，照抄 emacs-solo 的 wordmark 段，不支持该字符就用空格占位
    ;; 保持对齐（emacs-solo 原版就是这么处理的，不是简单的条件为空）。
    (:propertize
     (:eval (if (char-displayable-p ?λ) "λ  " "   "))
     face font-lock-keyword-face)
    ;; evil 状态段：emacs-solo 不用 evil，本仓库用，是唯一的结构性偏离。
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
    (:eval (and (bound-and-true-p flymake-mode) flymake-mode-line-counters))
    "  "
    mode-line-misc-info
    "  "))

;; 文件名格式/行列号格式，照抄 emacs-solo 的几个配套 setq。
(setq-default mode-line-buffer-identification '(" %b")
              mode-line-position-column-line-format '(" %l:%c"))

;; 跟之前一致：只在下面这几个 mode-hook 里 setq-local，其余缓冲区
;; （magit/eshell/help/*scratch*/popper 弹窗…）保持 early-init.el 设的
;; `(setq-default mode-line-format nil)'，即**完全没有 mode-line**——刻意的极简取向。
;; 这一点 emacs-solo 没有（它是全局 `setq-default'），沿用本仓库既有做法不改，
;; 跟这条 bar 本身的分段取舍无关——那管的是它长什么样，不是它在哪些 buffer
;; 里出现。想要「其余也都有 mode-line」的兜底，加一行
;; `(setq-default mode-line-format my-ui-mode-line-format)' 即可。

;; 进这些 mode 时清一次缓存：同一个 buffer 换了文件/换了 mode，分支和 project 都可能变。
(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook dired-mode-hook))
  (add-hook hook (lambda ()
                   (setq my-ui--ml-vc-cache nil
                         my-ui--ml-project-cache nil)
                   (setq-local mode-line-format my-ui-mode-line-format))))

(provide 'init-mode-line)
