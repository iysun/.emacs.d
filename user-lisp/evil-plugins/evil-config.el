;; evil-config.el 	-*- lexical-binding: t -*-
;; 启用 Evil 全局配置

;; evil-want-* 必须在 evil 加载【前】设置。
;; evil-want-keybinding t（默认）：让 evil 加载自带的 evil-keybindings.el，为 dired/help/
;; ibuffer 等 special mode 提供基础 evil 键位。已移除 evil-collection，故用默认 t 而非 nil
;; （设 nil 是给 evil-collection 接管用的，没有它时会导致 special mode 完全没有 evil 键位）。
(progn
  (setq evil-want-integration t)                ; 与 Emacs minor modes 集成
  (setq evil-want-keybinding t)
  (setq evil-shift-width 2)
  (setq evil-search-module 'evil-search)        ; 必须！支持 gn / cgn
  (setq evil-respect-visual-line-mode t)        ; 在 visual-line-mode 中按行移动
  (setq evil-cross-lines t)                     ; j/k 可跨软换行行（类似 Vim）
  (setq evil-undo-system 'undo-redo)            ; 使用 Emacs 的 undo-tree 或简易 undo-redo
  )

;; 本文件顶层用了 `evil-define-text-object'（宏）。byte-compiler 不会执行 `(evil-mode 1)'，
;; 故编译期需顶层 require 让宏可用，否则生成坏 .elc（加载报 void-variable evil-a-between）。
;; 放在 evil-want-* 之后，保证运行时这些变量先于 evil 设好（避免 issue #60）。
(require 'evil)

(evil-mode 1)
(with-eval-after-load 'evil
  (require 'evil-surround)
  (global-evil-surround-mode 1)
  (require 'evil-visualstar)
  (global-evil-visualstar-mode)
  (require 'evil-commentary)
  (evil-commentary-mode)
  )

;; 输入法切换（跨平台）已挪到 user-lisp/evil-plugins/ime.el（`my/switch-to-english-input-method'
;; + C-SPC 绑定），early-init.el 阶段就加载好了，这里不用再定义。


;; evil-textobj-between
(defgroup evil-textobj-between nil
  "Text object between for Evil"
  :prefix "evil-textobj-between-"
  :group 'evil)

(defcustom evil-textobj-between-i-key "f"
  "Keys for evil-inner-between"
  :type 'string
  :group 'evil-textobj-between)
(defcustom evil-textobj-between-a-key "f"
  "Keys for evil-a-between"
  :type 'string
  :group 'evil-textobj-between)

(defun evil-between-range (count beg end type &optional inclusive)
  (ignore-errors
    (let ((count (abs (or count 1)))
          (beg (and beg end (min beg end)))
          (end (and beg end (max beg end)))
          (ch (evil-read-key))
          beg-inc end-inc)
      (save-excursion
        (when beg (goto-char beg))
        (evil-find-char (- count) ch)
        (setq beg-inc (point)))
      (save-excursion
        (when end (goto-char end))
        (backward-char)
        (evil-find-char count ch)
        (setq end-inc (1+ (point))))
      (if inclusive
          (evil-range beg-inc end-inc)
        (if (and beg end (= (1+ beg-inc) beg) (= (1- end-inc) end))
            (evil-range beg-inc end-inc)
          (evil-range (1+ beg-inc) (1- end-inc)))))))

(evil-define-text-object evil-a-between (count &optional beg end type)
  "Select range between a character by which the command is followed."
  (evil-between-range count beg end type t))
(evil-define-text-object evil-inner-between (count &optional beg end type)
  "Select inner range between a character by which the command is followed."
  (evil-between-range count beg end type))

(define-key evil-outer-text-objects-map evil-textobj-between-a-key
            'evil-a-between)
(define-key evil-inner-text-objects-map evil-textobj-between-i-key
            'evil-inner-between)

;; ---- 词运动 / 分词（word motion & subwords）----
;; 口径（最终）：w/b/e 与 iw/aw 按「整词」（identifier 级 [[:word:]_-]+，即
;; fooBarBaz / foo-bar-baz / foo_bar_baz 各算一个）；i SPC w / a SPC w 按「subword」。
;;
;; 实现整词：把 evil 的 `evil-word' 词运动换成整词运动。`w/b/e` 走 `forward-thing 'evil-word'，
;; `iw/aw` 走 `bounds-of-thing-at-point 'evil-word'`（thingatpt 通用算法再经 forward-thing），
;; 两条路都解析到 `forward-evil-word'——所以 defalias 这一个函数，词运动与 iw/aw 一起变整词。
;;
;; ⚠ 字符类写死 [[:word:]_-] 而不用语法表：'-' 在 basic 模式是标点、在 lisp 模式是符号，
;; 写死才能跨 mode 一致；[:word:] 含 CJK，故中文整段也算一个整词。
;;
;; 启用 `global-subword-mode'：让 Emacs 自身的词命令 M-f/M-b/M-d… 也按 subword 切。
;; （Emacs 31 的 subword-mode 经 `find-word-boundary-function-table' 让 `forward-word' 认
;; camelCase 边界——不是改键、不是 advice，所以绑在 `forward-word' 上的 M-f/M-b/M-d 一并生效。）
;; evil 侧不依赖它：w/b/e 走 skip-chars 整词运动，i␣w/a␣w 直接调 subword-forward，开不开都不影响。
(require 'subword)
(global-subword-mode t)

(defun forward-evil-whole-word (&optional count)
  "整词运动：前移 COUNT 个整词的末尾；COUNT 为负则回退到词首。
整词 = [[:word:]_-]+（字母数字/CJK + 下划线 + 连字符）。

返回**未能移动的整词数**（0 = 成功）——这是 evil `forward-op'/`forward-thing' 的约定：
`evil-forward-beginning'/`evil-forward-nearest' 内部用 `(zerop (forward-thing ...))' 判断成功。
⚠ 必须返回数字；返回 nil 会让 `evil-bounds-of-not-thing-at-point' 的 `(zerop ...)' 报
wrong-type-argument（曾导致 aw/b 报错、w 落点错位）。"
  (let* ((count (or count 1))
         (n (abs count))
         (dir (if (> count 0) 1 -1)))
    (while (and (> n 0)
                (let ((start (point)))
                  (if (> dir 0)
                      (progn (skip-chars-forward "^[:word:]_-")
                             (skip-chars-forward "[:word:]_-"))
                    (skip-chars-backward "^[:word:]_-")
                    (skip-chars-backward "[:word:]_-"))
                  (/= start (point))))
      (setq n (1- n)))
    n))

;; 让 `evil-word'（w/b/e、iw/aw、双击选词…）都按整词。
;; `forward-thing 'evil-word' 解析到 (intern-soft "forward-evil-word")，即下面这个 defalias。
;; ⚠ `*' / `#' 不在此列：evil-search 模块下它们被 `evil-select-search-module' 改绑到
;;   evil-ex-*-word-*，取词用 Emacs `word'（不含 -）而非 `evil-word'，故单独处理——
;;   见下面「搜索光标下的整词」一节。
(defalias #'forward-evil-word #'forward-evil-whole-word)

;; ---- 搜索光标下的整词：`*' / `#' / `g*' / `g#' ----
;; 背景：`evil-search-module' 的 :set（`evil-select-search-module'）会把 `*' 从
;; `evil-search-word-forward' 换成 `evil-ex-search-word-forward'，后者经
;; `evil-ex-start-word-search' 用 Emacs `word'（[[:word:]]，不含 `-'）取词
;; → `foo-bar' 只搜到 `foo'，不吃上面的整词 alias。这里改绑成自建命令：取词走
;; `evil-word'（整词），搜索仍走 evil-ex（故 `gn' / `cgn' 照常可用）。
;;
;; ⚠ 词边界 `\<' / `\>' 基于语法表，`-' 不是 word 字符 → 取到 `-foo' / `foo-' /
;;   `--flag' 这类首尾带 `-' 的整词时，直接套 `\<...\>' 会**匹配不到**（实测
;;   `\<-foo\>' 匹配 `-foo' 得 nil）。故 bounded 时先去掉首尾的 `-'（`_' 是 word
;;   字符，不动），退化成搜内部词——等价 Vim 的 `*'（Vim 的 iskeyword 也不含 `-'）。
;;   unbounded（g*/g#）不加边界，原样搜。
(defun my/evil-ex-search-word-regex (string unbounded)
  "整词 STRING 的搜索正则。UNBOUNDED 时不加词边界、原样返回。"
  (if unbounded
      (regexp-quote string)
    (let ((w (replace-regexp-in-string "\\`-+\\|-+\\'" "" string)))
      (if (string-empty-p w)
          (regexp-quote string)         ; 整词全是 `-'，无从加边界
        (format "\\<%s\\>" (regexp-quote w))))))

(defun my/evil-ex-start-word-search (unbounded direction count)
  "同 evil 的 `evil-ex-start-word-search'，但取词用 `evil-word'（整词）。
词边界处理见上方说明。"
  (let* ((string (or (evil-find-thing (eq direction 'forward) 'evil-word)
                     (user-error "No word under point")))
         (regex (my/evil-ex-search-word-regex string unbounded)))
    (setq evil-ex-search-count count
          evil-ex-search-direction direction
          evil-ex-search-pattern
          (let (evil-ex-search-vim-style-regexp)
            (evil-ex-make-search-pattern regex))
          evil-ex-search-offset nil
          evil-ex-last-was-search t)
    (unless (equal regex (car evil-ex-search-history))
      (push regex evil-ex-search-history))
    (evil-push-search-history regex (eq direction 'forward)))
  (evil-ex-delete-hl 'evil-ex-search)
  (evil-ex-search-next count))

(evil-define-motion my/evil-ex-search-word-forward (count &optional _symbol)
  "搜索光标下的整词（前向）；走 evil-ex，故 `gn' / `cgn' 可用。"
  :jump t :type exclusive
  (interactive (list (prefix-numeric-value current-prefix-arg)))
  (my/evil-ex-start-word-search nil 'forward count))
(evil-define-motion my/evil-ex-search-word-backward (count &optional _symbol)
  "搜索光标下的整词（后向）；走 evil-ex，故 `gn' / `cgn' 可用。"
  :jump t :type exclusive
  (interactive (list (prefix-numeric-value current-prefix-arg)))
  (my/evil-ex-start-word-search nil 'backward count))
(evil-define-motion my/evil-ex-search-unbounded-word-forward (count &optional _symbol)
  "搜索光标下的整词（前向，不加词边界）＝ `g*'."
  :jump t :type exclusive
  (interactive (list (prefix-numeric-value current-prefix-arg)))
  (my/evil-ex-start-word-search t 'forward count))
(evil-define-motion my/evil-ex-search-unbounded-word-backward (count &optional _symbol)
  "搜索光标下的整词（后向，不加词边界）＝ `g#'."
  :jump t :type exclusive
  (interactive (list (prefix-numeric-value current-prefix-arg)))
  (my/evil-ex-start-word-search t 'backward count))

(define-key evil-motion-state-map "*"  #'my/evil-ex-search-word-forward)
(define-key evil-motion-state-map "#"  #'my/evil-ex-search-word-backward)
(define-key evil-motion-state-map "g*" #'my/evil-ex-search-unbounded-word-forward)
(define-key evil-motion-state-map "g#" #'my/evil-ex-search-unbounded-word-backward)

;; ---- i SPC w / a SPC w：subword ----
;; thing `evil-subword' 的 forward-op 用 `subword-forward'（按 camelCase/大小写边界切）。
(defun forward-evil-subword (&optional count)
  "Move forward COUNT subwords；返回未能移动的个数（0 = 成功），同 evil forward-op 约定。"
  (let* ((count (or count 1))
         (n (abs count))
         (dir (if (> count 0) 1 -1)))
    (while (and (> n 0)
                (let ((start (point)))
                  (subword-forward dir)
                  (/= start (point))))
      (setq n (1- n)))
    n))

(put 'evil-subword 'forward-op #'forward-evil-subword)

(evil-define-text-object evil-inner-subword (count &optional beg end type)
  "Select inner subword."
  (evil-select-inner-object 'evil-subword beg end type count))

(evil-define-text-object evil-a-subword (count &optional beg end type)
  "Select a subword plus adjacent whitespace.
不用 `evil-select-an-object'：它对「两对象之间无空白」的 subword 会多吞一个后继对象
（实测在 fooBarBaz 上会选成 fooBar），改为在 inner 范围上补相邻空白。"
  (let* ((range (evil-select-inner-object 'evil-subword beg end type count))
         (b (evil-range-beginning range))
         (e (evil-range-end range)))
    (if (and b e (< b e))
        (save-excursion
          (goto-char e)
          (let ((ws (skip-chars-forward " \t")))
            (if (> ws 0)
                (evil-range b (+ e ws) type :expanded t)
              (goto-char b)
              (let ((ws2 (skip-chars-backward " \t")))
                (evil-range (+ b ws2) e type :expanded t)))))
      range)))

(define-key evil-outer-text-objects-map (kbd "SPC w") 'evil-a-subword)
(define-key evil-inner-text-objects-map (kbd "SPC w") 'evil-inner-subword)

(provide 'evil-config)
