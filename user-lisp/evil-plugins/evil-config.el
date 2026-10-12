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
;; 之前这里用 Evil FAQ 的「整符号」配方：
;;   (fset 'original-forward-evil-word ...) (defalias #'forward-evil-word #'forward-evil-symbol)
;; 后果：w≡W（`w' 变成按空白/符号切）、camelCase 不切、中文整句一坨，还顺手覆盖了 evil
;; `forward-evil-word' 自带的标点串 + CJK 词类别处理。现删除该 override，恢复 evil 原版。
;;
;; ⚠ 关于 subword：Emacs 31 的 `subword-mode' 通过 `find-word-boundary-function-table'
;; （buffer-local char-table）改写 `forward-word' 的词边界——**不是**改键、**不是** advice。
;; 而 `forward-thing 'evil-word' → forward-evil-word' 内部正是调 `forward-word'，所以只要
;; subword-mode 开着，w/b/e（以及 dw/cw/iw/aw…）就会自动在 camelCase 处分词，无需再 override。
(require 'subword)
(global-subword-mode t)

;; ---- agw/igw：整词（identifier 级；与 subword 级的 iw/aw 相对）----
;; 目标：w/b/e 与 iw/aw 按 subword 分词；agw/igw 把整块标识符当一个词。
;; 例：fooBarBaz / foo-bar-baz / foo_bar_baz 各算一个整词。
;; 用显式字符类 [[:word:]_ -] 而非语法表：'-' 在 basic 模式是标点、在 lisp 模式是符号，
;; 写死才能跨 mode 一致（[:word:] 含 CJK，故中文整段也当一个整词）。
(defconst my/whole-word-chars "[:word:]_-"
  "整词字符集：[[:word:]] + 下划线 + 连字符（skip-chars 语法，`-' 置末尾按字面量）。")

(defun my/bounds-of-evil-whole-word ()
  "光标位于整词内时返回 (BEG . END)，否则 nil。"
  (save-excursion
    (let ((p (point)))
      (skip-chars-backward my/whole-word-chars)
      (let ((beg (point)))
        (skip-chars-forward my/whole-word-chars)
        (let ((end (point)))
          (when (and (< beg end) (<= beg p) (<= p end)
                     ;; 至少含一个 word 字符：避免把孤立的 -- / __ 当整词
                     (save-excursion (goto-char beg) (looking-at-p "[[:word:]]")))
            (cons beg end)))))))

(defun forward-evil-whole-word (&optional count)
  "Move forward COUNT whole words (identifier level)."
  (let ((count (or count 1)))
    (if (> count 0)
        (dotimes (_ count)
          (skip-chars-forward "^[:word:]_-")
          (skip-chars-forward "[:word:]_-"))
      (dotimes (_ (- count))
        (skip-chars-backward "^[:word:]_-")
        (skip-chars-backward "[:word:]_-")))))

(put 'evil-whole-word 'forward-op #'forward-evil-whole-word)
(put 'evil-whole-word 'bounds-of-thing-at-point #'my/bounds-of-evil-whole-word)

(evil-define-text-object evil-inner-whole-word (count &optional beg end type)
  "Select inner whole word (identifier: fooBarBaz / foo-bar-baz / foo_bar_baz)."
  (evil-select-inner-object 'evil-whole-word beg end type count))

(evil-define-text-object evil-a-whole-word (count &optional beg end type)
  "Select a whole word (identifier) plus adjacent whitespace.
不用 `evil-select-an-object'：它对「两对象之间无空白」的对象会多吞一个后继对象
（实测 `agw` 在 `fooBarBaz` 上会选到 `fooBar'）。改为在 inner 范围上补相邻空白。"
  (let* ((range (evil-select-inner-object 'evil-whole-word beg end type count))
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

(define-key evil-outer-text-objects-map (kbd "gw") 'evil-a-whole-word)
(define-key evil-inner-text-objects-map (kbd "gw") 'evil-inner-whole-word)

(provide 'evil-config)
