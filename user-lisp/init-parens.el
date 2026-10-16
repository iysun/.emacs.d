;; init-parens.el 	-*- lexical-binding: t -*-

(defcustom my-paren-fade 0.4
  "括号色中保留默认前色的比例：0 = 完全背景色（最淡），1 = 原色。越小越淡。"
  :type 'number :group 'faces)

(defcustom my-paren-auto-mode t
  "非 nil 时在 `prog-mode' 里自动开 `my-paren-mode'。"
  :type 'boolean :group 'faces)

(defface my-paren-face '((t :inherit shadow))
  "默认（很淡）的括号。实际前景色由 `my-paren-setup-faces' 按主题重设。")

(defface my-paren-mismatch-face '((t :inherit error))
  "未匹配 / 不配对的括号。")

;; 机制改编自 rainbow-delimiters（GPLv3）

(defun my-paren--ineligible-p (loc ppss syntax-code)
  "LOC 处的字符是否**不该**染色。
PPSS 是 LOC 处的 `parse-partial-sexp' 状态，SYNTAX-CODE 是 LOC 处原始语法描述符的 car。
不该染色的情况：字符串内、注释内、被转义、双字符 opener 的一半。
（照搬 rainbow-delimiters 的 `rainbow-delimiters--char-ineligible-p'。）"
  (or
   (nth 3 ppss)
   (nth 4 ppss)
   (nth 5 ppss)
   (cond
    ((/= 0 (logand #x10000 syntax-code))
     (/= 0 (logand #x20000 (or (car (syntax-after (1+ loc))) 0))))
    ((/= 0 (logand #x20000 syntax-code))
     (/= 0 (logand #x10000 (or (car (syntax-after (1- loc))) 0))))
    (t nil))))

(defconst my-paren--font-lock-keywords '(my-paren--propertize)
  "本模块挂到 `font-lock' 的关键词。")

(defun my-paren--propertize (end)
  "给 point..END 里该染的括号 prepend `my-paren-face' / `my-paren-mismatch-face'。
font-lock 关键词函数。"
  (let ((last-ppss-pos (point))
        (ppss (syntax-ppss)))
    (while (> end (progn (skip-syntax-forward "^()" end)
                         (point)))
      (let* ((delim-pos (point))
             (delim-syntax (syntax-after delim-pos)))
        (setq ppss (parse-partial-sexp last-ppss-pos delim-pos nil nil ppss))
        (setq last-ppss-pos delim-pos)
        (forward-char)
        (let* ((code (car delim-syntax))
               (opening-p (= 4 (logand #xFFFF code)))   ; class 4 = 开括号
               (open-pos (nth 1 ppss))
               (mismatch-p (and (not opening-p)
                                (not (and open-pos
                                          (eq (cdr delim-syntax)
                                              (char-after open-pos)))))))
          (unless (my-paren--ineligible-p delim-pos ppss code)
            ;; 必须 prepend，否则压不过 treesit 的 font-lock-bracket-face。
            (font-lock-prepend-text-property
             delim-pos (1+ delim-pos) 'face
             (if mismatch-p 'my-paren-mismatch-face 'my-paren-face))))))
    nil))

(define-minor-mode my-paren-mode
  "给括号上淡色（`my-paren-face'）；光标处那一对由 `show-paren' 强调。"
  :lighter ""
  :keymap nil
  (font-lock-remove-keywords nil my-paren--font-lock-keywords)
  (when my-paren-mode
    (font-lock-add-keywords nil my-paren--font-lock-keywords 'append)
    (set (make-local-variable 'jit-lock-contextually) t)
    ;; 它会破坏「ppss ≡ 从 point-min 起 parse-partial-sexp」的前提、使配对判断出错，直接禁用。
    (when (or (bound-and-true-p syntax-begin-function)
              (bound-and-true-p font-lock-beginning-of-syntax-function))
      (syntax-ppss-flush-cache 0))
    (when (boundp 'syntax-begin-function)
      (set (make-local-variable 'syntax-begin-function) nil))
    (when (boundp 'font-lock-beginning-of-syntax-function)
      (set (make-local-variable 'font-lock-beginning-of-syntax-function) nil)))
  (when font-lock-mode
    (if (fboundp 'font-lock-flush)
        (font-lock-flush)
      (with-no-warnings (font-lock-fontify-buffer)))))

(when my-paren-auto-mode
  (add-hook 'prog-mode-hook #'my-paren-mode))

(defun my-paren-setup-faces (&optional _theme _body)
  "按当前主题的 default fg/bg 重算括号 / show-paren 的 face。"
  (let* ((bg (my-ui--bg))
         (fg (my-ui--fg 'default "#d4d4d4"))
         (faint (my-ui--blend-fg fg bg my-paren-fade)))
    (set-face-attribute 'my-paren-face nil
                        :foreground faint :background 'unspecified :weight 'normal)
    (set-face-attribute 'my-paren-mismatch-face nil
                        :foreground (my-ui--fg 'error "#ff5555")
                        :background 'unspecified :weight 'bold)
    ;; 光标处用主题强调色加粗、不加背景块（加背景块字形会被画成背景色，看着像括号没了）。
    (set-face-attribute 'show-paren-match nil
                        :foreground (my-ui--fg 'font-lock-keyword-face "#5fafd7")
                        :background 'unspecified
                        :weight 'bold :box nil :underline nil)))

(add-hook 'after-init-hook #'my-paren-setup-faces t)
(when (boundp 'enable-theme-functions)
  (add-hook 'enable-theme-functions #'my-paren-setup-faces))

(setq show-paren-style 'parenthesis
      show-paren-context-when-offscreen 'overlay
      blink-matching-paren-highlight-offscreen t)
(show-paren-mode 1)

(provide 'init-parens)
