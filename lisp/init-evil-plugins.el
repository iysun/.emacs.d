;; init-evil-plugins.el  -*- lexical-binding: t -*-
;; 顶层用了 `evil-define-text-object'（宏），编译期需先加载 evil（见 init-evil.el 同款修复）。
(require 'evil)

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

(define-key evil-outer-text-objects-map (kbd "lw") 'evil-a-little-word)
(define-key evil-inner-text-objects-map (kbd "lw") 'evil-inner-little-word)

(provide 'init-evil-plugins)
