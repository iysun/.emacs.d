;; init-completion.el   -*- lexical-binding: t -*-

;; Optionally use the `orderless' completion style.
;; (require 'orderless)
(progn
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles basic partial-completion))))
  )

;; marginalia 直接调用 compat 内部符号 compat--seconds-to-string，
;; 而 Emacs 31 上 compat 不再定义它（seconds-to-string 已内置）。
;; 上游未修复前保留此 shim。
(unless (fboundp 'compat--seconds-to-string)
  (defalias 'compat--seconds-to-string #'seconds-to-string))

;; (require 'marginalia)
(add-hook 'after-init-hook 'marginalia-mode)
;; (use-package vertico-posframe
;;   :ensure t
;;   :hook (vertico-mode . vertico-posframe-mode))


;; (require 'vertico)
(with-eval-after-load 'vertico
  (setq vertico-count 10)
  (setq vertico-cycle t)
  )
(add-hook 'after-init-hook  'vertico-mode)
(add-hook 'vertico-mode-hook  'vertico-reverse-mode)
(add-hook 'vertico-mode-hook  'vertico-multiform-mode)


;; (require 'embark)
;; 组合键 C-h 可以展示后续的有效按键
(setq prefix-help-command 'embark-prefix-help-command)
;; Embark 使用 posframe 打开
(progn 
  (defun posframe-display-buffer (buffer)
    (let ((default-fgc (face-attribute 'default :foreground))
          (default-bgc (face-attribute 'default :background))
          (hl (face-attribute 'highlight :background)))
      (when buffer (posframe-show
                    buffer
                    ;; :position (point)
                    :poshandler 'posframe-poshandler-frame-center
                    :font-height 1.0
                    :font-width 1.0
                    ;; :width 120
                    ;; :height 30
                    :border-width 5
                    :left-fringe 20
                    :right-fringe 20
                    :border-color hl
                    :background-color default-bgc))))
  (defun embark-get-buffer-pos-display (orig-fun)
    (interactive)
    (let* ((orig-result (funcall orig-fun)))
      (lambda (&optional keymap targets prefix)
        (let ((result (funcall orig-result keymap targets prefix)))
          (when (and result (windowp result))
            (posframe-display-buffer (window-buffer result))
            (delete-window result))))))
  (advice-add #'embark-verbose-indicator :around #'embark-get-buffer-pos-display)
  )

;; (require 'consult)
(progn
  ;; Tweak the register preview
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)
  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  ;; Optionally configure the narrowing key.
  (setq consult-narrow-key ",")
  )

(add-hook 'completion-list-mode-hook 'consult-preview-at-point-mode)

;; (require 'embark-consult)
;; (with-eval-after-load 'embark-consult
;;   (define-key minibuffer-mode-map (kbd "C-c C-o") 'embark-export)
;;   )
(add-hook 'embark-collect-mode-hook 'consult-preview-at-point-mode)

;; Auto completion - corfu
;;(unless (package-installed-p 'corfu)
;;(package-install 'corfu))

;; (require 'corfu)
;; 设置 corfu 变量（corfu-auto 由下面的补全风格切换按需设置，不在这里写死）
(progn
  ;; 自动弹窗的最小前缀长度（corfu-auto.el 的上游默认就是 3）。
  ;; 判定在 `corfu--capf-wrapper' 里，挡在 `corfu--compute' → all-completions 之前，
  ;; 所以它拦得住 LSP 请求本身、而不只是拦渲染。用 2 的话，`fm'/`st'/`er' 这种
  ;; 两字母前缀配上 gopls 的 `:completeUnimported t'（见 init-lsp.el）会让 gopls
  ;; 扫全 module 依赖图返回上千条。3 能收窄一个数量级。
  ;; 注意：capf 自报的 `:company-prefix-length' 优先级更高，而 `cape-wrap-super'
  ;; 恰好会带这个 key，所以 eglot buffer 里实际比较的是 cape 算出的 plen。
  (setq corfu-auto-prefix 3)
  ;; 触发字符：出现时忽略上面的前缀长度，立即弹窗（corfu-auto.el:111）。
  ;; `foo.' 之后的成员补全候选集小且准，正好避开 completeUnimported 的最坏路径；
  ;; 普通标识符仍要敲满 3 个字符。⚠ 触发字符走的是**同步**路径（不进 timer、
  ;; 也不做 tick 校验），敲 `.' 时会当场阻塞一次 LSP 往返。
  (setq corfu-auto-trigger ".")
  (setq corfu-preview-current nil)
  (setq corfu-auto-delay 0.2)
  (setq corfu-popupinfo-delay '(0.4 . 0.2))
  ;; 设置 corfu 字体
  (custom-set-faces
   '(corfu-border ((t (:inherit region :background unspecified)))))
  )
;; corfu / corfu-popupinfo / corfu-terminal 的启停交给下面的补全风格切换统一管理

;; corfu 配置
(with-eval-after-load 'corfu
  (keymap-set corfu-map "RET"
              `(menu-item "" nil :filter
                          ,(lambda (&optional _)
                             ;; 如果当前是 eshell 或 comint 模式，返回 nil (忽略 corfu 绑定)
                             ;; 否则返回 corfu-send (执行 corfu 的补全确认)
                             (unless (or (derived-mode-p 'eshell-mode 'comint-mode)
                                         (minibufferp))
                               #'corfu-send))))

  ;; corfu-map 里的 C-n/C-p 靠 `<remap> <next-line>'/`<remap> <previous-line>' 生效，
  ;; 但 evil insert 状态的 C-n/C-p 直接绑死在 evil-complete-next/-previous（vim 关键字补全）上，
  ;; 命令层级压根不经过 next-line/previous-line，remap 永远不会触发；而 evil 的
  ;; emulation-mode-map-alists 优先级又高于 corfu 挂在 minor-mode-overriding-map-alist
  ;; 上的 corfu-map，所以哪怕给 corfu-map 直接绑 C-n/C-p 也一样会被 evil 截胡。
  ;; 于是直接在 evil-insert-state-map 上按上下文分流：corfu 弹窗活着时转发给
  ;; corfu-next/-previous，否则维持 evil 原生的 C-n/C-p。
  (evil-define-key 'insert 'global (kbd "C-n")
    `(menu-item "" evil-complete-next :filter
                ,(lambda (cmd)
                   (if (and corfu-mode completion-in-region-mode)
                       #'corfu-next
                     cmd))))
  (evil-define-key 'insert 'global (kbd "C-p")
    `(menu-item "" evil-complete-previous :filter
                ,(lambda (cmd)
                   (if (and corfu-mode completion-in-region-mode)
                       #'corfu-previous
                     cmd))))
  )

;; Emacs 原生配置
;; TAB cycle if there are only few candidates
;; (setq completion-cycle-threshold 3)

;; Enable indentation+completion using the TAB key.
;; `completion-at-point' is often bound to M-TAB.
;; (setq tab-always-indent 'complete)

;; Emacs 30 and newer: Disable Ispell completion function.
(setq text-mode-ispell-word-completion nil)

;; Emacs 28 and newer: Hide commands in M-x which do not apply to the current mode.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; Add extensions - cape
;; cape-dabbrev 默认扫描所有 buffer，在 LSP 模式下会拖慢补全触发，限制为只查当前 buffer
(setq cape-dabbrev-check-other-buffers nil)
(add-to-list 'completion-at-point-functions #'cape-dabbrev)
(add-to-list 'completion-at-point-functions #'cape-file)
(add-to-list 'completion-at-point-functions #'cape-elisp-block)
(add-to-list 'completion-at-point-functions #'cape-keyword)
(add-to-list 'completion-at-point-functions #'cape-abbrev)

;; cape-wrap-buster 已移除：它每次按键都绕过 eglot 缓存强制重新请求 LSP，是输入卡顿的主因。
;; eglot 29+ 自身的缓存机制已足够，无需 buster。

;; 行内补全预览（Emacs 30+ 内置）：打字时在光标后 inline 显示候选词（灰字），
;; 不弹窗，与 corfu 互补。是否在 prog/text/eshell/comint 四类 buffer 里挂载
;; 由下面的补全风格切换（my/completion--set-preview-hooks）控制，
;; 这里只配置它自身的行为参数。
;;
;; ⚠ 「不发 LSP 请求」是**错的**，除非显式隔离——见下面的 advice。
;; `completion-preview--update' 直接 run-hook-wrapped 全局的
;; `completion-at-point-functions'，没有独立的 capf 列表可配。而 init-lsp.el 里
;; eglot-managed-mode-hook 把 `cape-capf-super'（含 eglot）塞在了该列表最前面，
;; 于是每次预览都会走到 eglot 的 table。更糟的是 `cape-wrap-super' 的 table
;; 在 try-completion 分支里也调 `cape--super-all'（即 all-completions），
;; 所以哪怕只求一个前缀预览也会触发完整的 `:textDocument/completion' 同步请求；
;; 而 `eglot--request' 开头无条件 `eglot--signal-textDocument/didChange',
;; 连 `eglot-send-changes-idle-time' 的节流都一并绕过。
;; 叠加 gopls 的 `:completeUnimported t'，1~2 个字符的前缀就能让 gopls 扫全 module
;; 索引返回上千条，再全量过滤 + 排序 —— 这就是 manual 档下打字卡顿的来源。
;; （`while-no-input' / `:cancel-on-input t' 救不了：能取消的只是等待，
;;   响应解析和排序的开销已经付掉了。）
(defvar my/completion-preview-capfs
  (list #'cape-dabbrev #'cape-keyword #'cape-file)
  "行内预览专用的 capf 列表：只用本地廉价源，绝不含 LSP。
LSP 候选走手动触发（C-M-i / `my/lsp-complete'）或 auto 档的 corfu。")

;; ---- eshell 里的例外：参数位要走 pcomplete ----
;; 上面那份 capf 列表对 eshell 是错的：eshell 唯一有用的补全源是它自己的
;; `pcomplete-completions-at-point'（buffer-local），被这里换掉之后，`cat init-f'
;; 这种补文件名的场景预览完全没候选；只有 `echo hel' 这类靠 cape-dabbrev 从 buffer
;; 里的历史命令行蒙出来的还能出。
;;
;; 但也不能无脑把 pcomplete 加回来——它在**命令位**（还在敲命令名、后面没空格）要
;; 枚举整个 `exec-path' 找可执行文件，实测 `gi' 125ms 首次 / 81.5ms 每次、`ec'
;; 71.6ms，而参数位（补文件名）只要 ~1ms。所以按位置分流：参数位交给 pcomplete，
;; 命令位不调它——命令名靠 cape-dabbrev 从本 buffer 已有的历史命令里补，1.5ms 够用。
(defun my/completion-preview--eshell-in-args-p ()
  "point 是否已经离开命令名那一段（命令名与 point 之间出现过空白）。
起点用 `field-beginning'：提示符文本带 `field' = \\='prompt（`eshell-emit-prompt' 加的），
输入区是另一个 field，所以这里取到的就是本次输入的开头，不会把提示符里的空格算进去。"
  (let ((beg (field-beginning (point) t)))
    (string-match-p "[ \t]" (buffer-substring-no-properties beg (point)))))

(defun my/completion-preview--eshell-pcomplete ()
  "只在参数位生效的 pcomplete capf，供行内预览用（理由见上面的注释）。
⚠ 必须补上 `:exclusive no'：`completion-preview--capf-wrapper' 在一个 capf 给不出
候选时会返回 \\='(nil) 来**阻断**后面的 capf（只有声明了 `:exclusive no' 的才放行），
而 pcomplete 没声明。不补的话，参数位上但 pcomplete 无候选的输入（如 `echo hel'）
会被它挡住，落不到 cape-dabbrev，历史提示就没了。plist 里先出现的键优先，所以万一
pcomplete 以后自己带了 `:exclusive'，这里追加的这份会被自动忽略，不会改变它的意图。"
  (when (and (fboundp 'pcomplete-completions-at-point)
             (my/completion-preview--eshell-in-args-p))
    (when-let* ((res (pcomplete-completions-at-point)))
      (append res '(:exclusive no)))))

(defun my/completion-preview--capfs ()
  "预览该用的 capf 列表。
eshell/comint 里最前面放 `cape-history'——补的是 shell 历史（eshell 走
`eshell-history-ring'，即 var/eshell/history 那份持久化历史；comint 走
`comint-input-ring'），从输入行开头整行匹配，这才是 fish 那种\"敲前几个字母就把上次
的整条命令灰着显示出来\"的行为，也正是当年 capf-autosuggest 干的事。
`cape-dabbrev' 顶替不了它：dabbrev 扫的是**当前 buffer 的文本**，只能补到本次会话里
还留在屏幕上的词，重开一个 eshell 就什么都没有。

`cape-history' 自带 `:exclusive no'（没候选时放行后面的 capf）和
`:display-sort-function' / `:cycle-sort-function' = `identity'，
`completion-preview--try-table' 会读这两个 metadata，所以候选保持**最近优先**而不是
被默认的\"按长度+字母序\"重排——历史补全必须最近优先才对。

eshell 里第二条是「只在参数位生效的 pcomplete」：历史没命中时才轮到它补文件名。
comint 不加 pcomplete：那边的命令补全同样要扫 PATH，坑一样，且没有 eshell 这种统一
入口，留待真需要时再单独处理。"
  (cond
   ((derived-mode-p 'eshell-mode)
    (append (list #'cape-history #'my/completion-preview--eshell-pcomplete)
            my/completion-preview-capfs))
   ((derived-mode-p 'comint-mode)
    (cons #'cape-history my/completion-preview-capfs))
   (t my/completion-preview-capfs)))

(defun my/completion-preview--local-capfs (orig &rest args)
  "让 `completion-preview--update' 只看 `my/completion-preview--capfs' 给出的列表。"
  (let ((completion-at-point-functions (my/completion-preview--capfs)))
    (apply orig args)))

(with-eval-after-load 'completion-preview
  (advice-add 'completion-preview--update :around
              #'my/completion-preview--local-capfs)
  ;; 默认 3。调到 1 会让预览在只敲一个字符时就触发，候选集最大、最贵。
  ;; 隔离掉 LSP 之后 2 是安全的（cape-dabbrev 只扫当前 buffer）。
  (setq completion-preview-minimum-symbol-length 2)
  ;; 默认 nil = 每敲一个字就在 post-command 里同步跑一遍 completion-at-point-functions，
  ;; 零防抖；当初 profiler 里 completion-preview--post-command 占大头就是因为这个，
  ;; 于是先加到了 0.2。但 0.2 是**在预览源还含 LSP 时**定的保守值，现在源已被上面的
  ;; advice 锁死成 cape-dabbrev/keyword/file 三个纯本地源，实测一次更新只要 1~3ms
  ;; （11KB 配置文件 0.9~3.3ms；335KB 的 eat.el 也只有 2~3.4ms，30 次调用零 GC），
  ;; 0.2 的等待反而成了预览"慢半拍"的唯一来源，故降到 0.05。
  ;;
  ;; 为什么不干脆设 nil：0.05 已经看不出延迟（人眼阈值 ~100ms），却仍能把连打时的
  ;; 每次按键合并成一次计算，顺带消掉逐字刷新的闪烁；nil 则是每个按键都真跑一遍。
  ;;
  ;; ⚠ 调这个值不会把 LSP 放回预览路径：`completion-preview--show' 里 idle-delay
  ;; 只决定"立刻算"还是"挂 idle timer"，两条路最终都落到被 advice 包住的
  ;; `completion-preview--update'（capf 链就是在它里面 run-hook-wrapped 的）。
  (setq completion-preview-idle-delay 0.05)
  ;; evil insert 模式下退格/删除后也刷新行内预览
  (dolist (cmd '(evil-delete-backward-char
                 evil-delete-backward-char-and-join
                 evil-delete-char))
    (push cmd completion-preview-commands))
  ;; M-n/M-p 与 diff-hl 的 evil insert 绑定冲突，不覆盖；用 TAB 确认，C-M-i 看完整列表
  )

;; ------------------------------------------------------------------
;; 补全风格切换：corfu 自动弹出 / corfu 手动触发+行内预览 / 仅行内预览
;; 用法仿照 switch-emacs-theme（见 init-ui.el）：交互选择、立即生效、
;; customize-save-variable 存进 custom.el，下次启动 use-completion-style 自动恢复。
;; ------------------------------------------------------------------

(defconst my/completion-styles '(auto manual preview-only)
  "可选补全风格：
auto         corfu 自动弹出（打字即弹），关闭行内预览；
manual       corfu 仅手动触发（C-M-i / my/lsp-complete），开启行内预览；
preview-only 完全关闭 corfu 弹窗，只保留行内预览。")

(defun my/completion--preview-hook-list ()
  '(prog-mode-hook text-mode-hook eshell-mode-hook comint-mode-hook))

(defun my/completion--set-preview-hooks (enable)
  "把 completion-preview-mode 挂/摘到 prog/text/eshell/comint 四个 hook 上。"
  (dolist (hook (my/completion--preview-hook-list))
    (if enable
        (add-hook hook #'completion-preview-mode)
      (remove-hook hook #'completion-preview-mode))))

(defun my/completion--sync-preview-buffers (enable)
  "把已打开、属于上述四类 major-mode 的 buffer 里的 completion-preview-mode 同步到 ENABLE。"
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'prog-mode 'text-mode 'eshell-mode 'comint-mode)
        (completion-preview-mode (if enable 1 -1))))))

(defun my/completion--set-corfu (enable)
  "联动 global-corfu-mode 及其 popupinfo/terminal 全局子模式。三者都是 :global t，
用显式 1/-1 而非 hook 里的隐式 toggle，避免反复切换风格后状态漂移。"
  (global-corfu-mode (if enable 1 -1))
  (corfu-popupinfo-mode (if enable 1 -1))
  (unless (display-graphic-p)
    (corfu-terminal-mode (if enable 1 -1))))

(defun my/apply-completion-style (style)
  "按 STYLE（auto/manual/preview-only）应用补全行为，对已打开的 buffer 立即生效。"
  (pcase style
    ('auto
     (setq corfu-auto t)
     (my/completion--set-corfu t)
     (my/completion--set-preview-hooks nil)
     (my/completion--sync-preview-buffers nil))
    ('manual
     (setq corfu-auto nil)
     (my/completion--set-corfu t)
     (my/completion--set-preview-hooks t)
     (my/completion--sync-preview-buffers t))
    ('preview-only
     (my/completion--set-corfu nil)
     (my/completion--set-preview-hooks t)
     (my/completion--sync-preview-buffers t))
    (_ (error "未知补全风格: %s" style))))

(defun switch-completion-style (style)
  "交互切换补全风格并持久化到 custom.el（仿 switch-emacs-theme）。"
  (interactive
   (list
    (intern (completing-read
             "select completion style: "
             (mapcar #'symbol-name my/completion-styles)
             nil t))))
  (my/apply-completion-style style)
  (customize-save-variable 'custom-completion-style style))

(defun use-completion-style ()
  (my/apply-completion-style
   (if (and (boundp 'custom-completion-style)
            (memq custom-completion-style my/completion-styles))
       custom-completion-style
     'manual)))
(add-hook 'after-init-hook 'use-completion-style)

(provide 'init-completion)
