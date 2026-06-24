;; init-evil.el 	-*- lexical-binding: t -*-
;; 启用 Evil 全局配置

;; 本文件顶层用了 `evil-define-text-object'（宏）。byte-compiler 不会执行 `(evil-mode 1)'，
;; 故编译期需顶层 require 让宏可用，否则生成坏 .elc（加载报 void-variable evil-a-between）。
(require 'evil)

(progn
  (setq evil-want-integration t)                ; 与 Emacs minor modes 集成
  (setq evil-want-keybinding nil)
  (setq evil-shift-width 2)
  (setq evil-search-module 'evil-search)        ; 必须！支持 gn / cgn
  (setq evil-respect-visual-line-mode t)        ; 在 visual-line-mode 中按行移动
  (setq evil-cross-lines t)                     ; j/k 可跨软换行行（类似 Vim）
  (setq evil-undo-system 'undo-redo)            ; 使用 Emacs 的 undo-tree 或简易 undo-redo
  )

(evil-mode 1)
(with-eval-after-load 'evil
  (require 'evil-collection)
  (evil-collection-init)
  (require 'evil-surround)
  (global-evil-surround-mode 1)
  (require 'evil-visualstar)
  (global-evil-visualstar-mode)
  (require 'evil-commentary)
  (evil-commentary-mode)
  )

;; 输入法切换（跨平台，均带 guard）：
;;   Linux/macOS 用 fcitx5-remote；Windows 用 im-select.exe。
;;   找不到对应程序时静默跳过，避免在没有该程序的平台上报错。
(defvar my/im-select-path "d:/im-select.exe"
  "Windows 上 im-select.exe 的路径，可按需修改。")

(defun my/switch-to-english-input-method ()
  "退出插入态时把输入法切到英文。"
  (cond
   ((eq system-type 'windows-nt)
    (when (file-exists-p my/im-select-path)
      (call-process my/im-select-path nil 0 nil "1033")))
   ((memq system-type '(gnu/linux darwin))
    (when (executable-find "fcitx5-remote")
      (call-process "fcitx5-remote" nil 0 nil "-c")))))

(add-hook 'evil-insert-state-exit-hook #'my/switch-to-english-input-method)

;; C-SPC 激活输入法：仅在 Linux/macOS（有 fcitx5-remote）保留此行为；
;; Windows 上不劫持 C-SPC，保留默认 set-mark-command。
(when (and (memq system-type '(gnu/linux darwin))
           (executable-find "fcitx5-remote"))
  (global-set-key (kbd "C-SPC")
                  (lambda () (interactive)
                    (call-process "fcitx5-remote" nil 0 nil "-o"))))


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

;; evil-little-word
;; Turn on subword-mode everywhere
(global-subword-mode t)
;; Backup the original 'forward-evil-word' function before overriding it.
(fset 'original-forward-evil-word (symbol-function 'forward-evil-word))
;; From the Evil FAQ.
;; Defaults all word movements, including editing operations, to 
;; 'whole symbols', which is what we want by default.
(defalias #'forward-evil-word #'forward-evil-symbol)

;; custom evil-select-an-object and evil-select-inner-object thing, evil-***
;; (defun forward-evil-o-word (&optional count)
;;   "Forward by little words."
;;   (original-forward-evil-word count))

(evil-define-text-object evil-a-little-word (count &optional beg end type)
  "Select a little word."
  ;; (evil-select-an-object 'evil-o-word beg end type count))
  (evil-select-an-object 'word beg end type count))

(evil-define-text-object evil-inner-little-word (count &optional beg end type)
  "Select inner little word."
  ;; (evil-select-inner-object 'evil-o-word beg end type count))
  (evil-select-inner-object 'word beg end type count))

(define-key evil-outer-text-objects-map (kbd "gw") 'evil-a-little-word)
(define-key evil-inner-text-objects-map (kbd "gw") 'evil-inner-little-word)

(provide 'init-evil)
