;; extensions/tab-line/tab-line.el 	-*- lexical-binding: t -*-
;;
;; tab-line 实现本体，由 `lisp/init-bars.el' `load'。原生 tab-line（按项目分组 +
;; 过滤 eglot buffer），替代 centaur-tabs，零第三方、零启动开销。两条 bar（mode-line +
;; tab-line）的共享工具函数（`my-ui--glyph-displayable-p' 等）和字号/内边距统一逻辑
;; 留在 `init-bars.el' 里，这个文件只管 tab-line 本身。
;;
;; ⚠ 本文件 `provide' 的符号是 `init-tab-line'，**不是** `tab-line'——内置库
;; `tab-line.el' 自己 `(provide 'tab-line)'，本文件如果也用这个名字会在同一个
;; load-path 上跟内置库撞名，`require' 到底加载哪个全看搜索顺序，随时炸。
;; tab-line 是 Emacs 内置库，这里提前 require（而非等 global-tab-line-mode 在
;; after-init-hook 里才隐式拉起）：下面 my/tab-line-ace-jump 用 `let' 动态覆写
;; `tab-line-tab-name-function'，字节/native 编译器要在编译期就看到该符号已被
;; `defcustom' 声明为 special，才会生成真正的动态绑定；否则会被当成普通词法变量
;; 静默失效（编译器本身会报 "Unused lexical variable" 提示这个坑）。
(require 'tab-line)

(defun my/tab-line-buffer-group-by-project (&optional buffer)
  "Group buffers by project root via project.el."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((dir (or (buffer-file-name) nil))
           (proj (project-current nil dir))
           (root (when proj (project-root proj))))
      (if (and root dir)
          (file-name-nondirectory (directory-file-name root))
        "Other"))))

(defun my/tab-line--popup-buffer-p (buf)
  "BUF 是否应该被排除在 tab-line 之外：popper 弹窗或 dashboard 首页。
两者过去在 centaur-tabs 下都是靠 `centaur-tabs-local-mode' 局部开启 tab 栏，
等价于「默认不出现在全局 tab 栏」——这里在过滤层面还原同样效果。
popper 未加载/`popper-mode' 未开启时 `popper-popup-p' 不存在，做特性探测短路；
`derived-mode-p' 对未定义的 mode symbol（如 dashboard 未安装）天然返回 nil，
不需要额外 `featurep' 守卫。"
  (with-current-buffer buf
    (or (derived-mode-p 'dashboard-mode)
        (and (featurep 'popper) (fboundp 'popper-popup-p)
             (popper-popup-p buf)))))

(defun my/tab-line-filter (buffers)
  "Filter out Eglot buffers / popper 弹窗 / dashboard buffer from tab-line."
  (let (result)
    (dolist (buf buffers (nreverse result))
      (let ((name (buffer-name buf)))
        (unless (or (and name
                          (let ((case-fold-search t))
                            (string-match-p "\\`\\s-*\\*eglot" name)))
                    (my/tab-line--popup-buffer-p buf))
          (push buf result))))))

;; ---- 标签文本：图标 + 修改标记（找回 centaur-tabs 的观感）----
;; 图标复用已装的 nerd-icons（mode-line 也在用，非新增依赖），取不到时回退纯文本。
(defvar-local my/tab-line--icon-cache 'unset
  "本 buffer 的 tab 图标串缓存。图标由 major-mode/文件类型决定、基本不变，
故按 buffer 缓存一次；'unset 表示尚未计算。
只缓存*成功*的结果——见 `my/tab-line--icon' 里的说明，别改成无条件缓存。")

(defun my/tab-line--icon (buffer)
  "返回 BUFFER 的 nerd-icons 文件类型图标串（含尾随空格）；
非 GUI / 无 nerd-icons / 出错 / 当前字体显示不出该图标时返回空串
（用 `my-ui--glyph-displayable-p' 探测，避免顶着一个豆腐块 □）。
结果缓存到 buffer-local，但**只缓存非空结果**：*scratch* 这类在 Emacs 启动早期
就存在的 buffer，第一次触发 tab-line 渲染的时机可能早于 `nerd-icons-font-family'
重定向就绪（取决于 `after-init-hook' 里各个函数的实际触发顺序，属于时序竞争，
不是每次都一样），这时算出来的是空串——如果连空串也当成\"算过了\"缓存死，
之后哪怕字体环境已经就绪，这个 buffer 的图标也永远不会重算，表现为\"改了配置、
重启 Emacs、图标还是没有\"。只缓存非空结果，空结果不缓存、留着下次重绘时再试一次，
一旦哪次成功了就定住——重试成本很低（tab-line 重绘本来就会调这个函数），
没必要为了省这几次重试引入这种「一次失败、永久失败」的缓存语义。"
  (with-current-buffer buffer
    (if (and (stringp my/tab-line--icon-cache)
             (not (string-empty-p my/tab-line--icon-cache)))
        my/tab-line--icon-cache
      (setq my/tab-line--icon-cache
            (or (and (display-graphic-p)
                     (require 'nerd-icons nil t)
                     (ignore-errors
                       (let ((ic (nerd-icons-icon-for-buffer)))
                         (and (my-ui--glyph-displayable-p ic)
                              (concat ic " ")))))
                "")))))

(defun my/tab-line-tab-name (buffer &optional _buffers)
  "tab 标签文本：图标 + buffer 名 +（文件改动未存时）● 标记。
覆写 `tab-line-tab-name-function'。截断仍由 `tab-line-tab-name-truncated-max' 处理。
非当前窗口正显示的 buffer，图标额外调暗——`nerd-icons-icon-for-buffer' 返回的图标串
自带显式 face（含图标专属颜色），只设 `tab-line-tab-inactive' 前景色压不过它，
须在图标串上另外*前插*一层 `shadow' face（`add-face-text-property' 的 APPEND=nil
即最高优先级）。只对拷贝操作、不动 buffer-local 的图标缓存，否则该 buffer 变为
选中标签时也会带着暗色。"
  (let* ((icon (my/tab-line--icon buffer))
         (icon (if (or (string-empty-p icon) (eq buffer (current-buffer)))
                   icon
                 (let ((dimmed (copy-sequence icon)))
                   (add-face-text-property 0 (length dimmed) 'shadow nil dimmed)
                   dimmed))))
    (concat icon
            (buffer-name buffer)
            (and (buffer-local-value 'buffer-file-name buffer)
                 (buffer-modified-p buffer)
                 " ●"))))

;; ---- 保留图标自己的 face：原生 tab-line 的一个真实 bug/限制 ----
;; `tab-line-tab-name-format-default'（内置 tab-line.el，`tab-line-tab-name-format-function'
;; 的默认值）拿到 `tab-line-tab-name-function' 返回的整条名字（我们在上面塞了图标，
;; 图标自带 `nerd-icons-*' 的颜色/字体族 face）之后，最后一步用
;; `(propertize name 'face face ...)' 把*整条*名字统一套上 tab 的容器 face
;; （`tab-line-tab-current'/`tab-line-tab-inactive' 等）。`propertize' 对 'face
;; 是整段覆盖式设置，不是叠加/追加——图标自己那段 face 就这样被冲掉了，图标的颜色/
;; 字体族全部换成容器 face 的，观感上图标要么变成大路货灰色文字色、要么因为容器 face
;; 没显式设某些图标需要的属性而干脆画不出来。
;;
;; 内置代码其实知道这个坑：给关闭按钮那段用的是 `add-face-text-property'
;; （APPEND=t，不覆盖已有 face），注释原文就是 "Don't overwrite the icon face"——
;; 只是这个处理只用在关闭按钮，没用在 tab 名字本身（我们的图标恰好嵌在名字里）。
;; 这里整个覆写 `tab-line-tab-name-format-function'（比 `tab-line-tab-name-function'
;; 更底层的定制点，能控制最终 propertize 这一步），把 name 那段的 `propertize'
;; 换成同样的 `add-face-text-property'（APPEND=t）：图标自带 face 里设过的属性
;; （字体族、颜色）保持最高优先级不被冲掉，图标没设的属性（比如选中态的下划线/加粗）
;; 仍然从容器 face 里继承下来。其余逻辑原样照抄
;; `tab-line-tab-name-format-default'（Emacs 31.0.91 版本），只改了这一处。
(defun my/tab-line-tab-name-format (tab tabs)
  "同 `tab-line-tab-name-format-default'，但保留 tab 名字里图标自带的 face。"
  (let* ((buffer-p (bufferp tab))
         (selected-p (if buffer-p
                         (eq tab (window-buffer))
                       (cdr (assq 'selected tab))))
         (name (if buffer-p
                   (funcall tab-line-tab-name-function tab tabs)
                 (cdr (assq 'name tab))))
         (face (if selected-p
                   (if (mode-line-window-selected-p)
                       'tab-line-tab-current
                     'tab-line-tab)
                 'tab-line-tab-inactive)))
    (dolist (fn tab-line-tab-face-functions)
      (setf face (funcall fn tab tabs face buffer-p selected-p)))
    (apply 'propertize
           (concat (let ((name (copy-sequence (string-replace "%" "%%" name))))
                     ;; 关键改动：`add-face-text-property' APPEND=t，不是 `propertize'。
                     (add-face-text-property 0 (length name) face t name)
                     (propertize name
                                 'keymap tab-line-tab-map
                                 'help-echo (if selected-p "Current tab"
                                              "Click to select tab")
                                 'follow-link 'ignore))
                   (let ((close (or (and (or buffer-p (assq 'buffer tab)
                                             (assq 'close tab))
                                         tab-line-close-button-show
                                         (not (eq tab-line-close-button-show
                                                  (if selected-p 'non-selected
                                                    'selected)))
                                         (if (and tab-line-close-modified-button-show
                                                  (tab-line-tab-modified-p tab buffer-p))
                                             tab-line-close-modified-button
                                           tab-line-close-button))
                                    "")))
                     (setq close (copy-sequence close))
                     (add-face-text-property 0 (length close) face t close)
                     close))
           `(
             tab ,tab
             ,@(if selected-p '(selected t))
             mouse-face tab-line-highlight))))

(defun my/tab-line-refresh (&rest _)
  "改动/保存后刷新 tab-line，让 ● 修改标记及时更新
（tab-line 的默认缓存键不含 `buffer-modified-p'，不主动刷会滞后）。"
  (force-mode-line-update t))

;; ---- 按组操作：关分组内 buffer / ace-jump 跳标签（找回 centaur-tabs 的控制）----
(defun my/tab-line--group-buffers (&optional group)
  "返回当前 tab-line 分组 GROUP（默认取当前 buffer 所在组）里、
实际会显示为 tab 的 buffer 列表，顺序与 tab-line 实际展示顺序一致。
直接复用 `tab-line-tabs-buffer-list-function'（已叠加本文件 eglot/popper/dashboard
过滤 advice）而不是另起一份枚举逻辑——否则很容易跟 tab-line 真实显示的内容跑偏。
排序复用 `tab-line-tabs-buffer-group-sort-function'，与 tab-line 内部
`tab-line-tabs-buffer-groups' 构建标签顺序时用的排序一致。"
  (let* ((group (or group (my/tab-line-buffer-group-by-project (current-buffer))))
         (bufs (seq-filter
                (lambda (b) (equal (my/tab-line-buffer-group-by-project b) group))
                (funcall tab-line-tabs-buffer-list-function))))
    (if (functionp tab-line-tabs-buffer-group-sort-function)
        (seq-sort tab-line-tabs-buffer-group-sort-function bufs)
      bufs)))

(defun my/tab-line-kill-group-buffers ()
  "关闭当前 tab 分组（当前 project）内的所有 buffer。
对应 centaur-tabs 的 `centaur-tabs-kill-all-buffers-in-current-group'。"
  (interactive)
  (let ((bufs (my/tab-line--group-buffers)))
    (if (null bufs)
        (message "当前分组没有可关闭的 buffer")
      (mapc #'kill-buffer bufs))))

(defun my/tab-line-kill-other-group-buffers ()
  "关闭当前 tab 分组内除当前 buffer 外的所有 buffer。
对应 centaur-tabs 的 `centaur-tabs-kill-other-buffers-in-current-group'。"
  (interactive)
  (let ((bufs (remq (current-buffer) (my/tab-line--group-buffers))))
    (if (null bufs)
        (message "当前分组没有其它 buffer 可关闭")
      (mapc #'kill-buffer bufs))))

(defconst my/tab-line-ace-jump-keys (append "asdfghjklqwertyuiopzxcvbnm" nil)
  "ace-jump 可选字母池，主键位优先。当前分组 tab 数超过 26 个时，
超出部分本轮不参与标注/跳转——这是刻意的简化：同一 project 分组同时开 26+ 个
buffer tab 的场景已经超出人工数字母找 tab 的实用范围，不值得为此加多字符标签。")

(defun my/tab-line-ace-jump (&optional arg)
  "为当前分组内每个 tab 标一个字母，按字母跳过去。
原生 tab-line 版对应 `centaur-tabs-ace-jump'。ARG 为 \\=`C-u C-u'（即 `(16)'）时，
改为关闭选中的 tab 而不是跳转过去；centaur-tabs 原版 `C-u' 单前缀的「交换 tab 顺序」
在原生 tab-line 下没有对应的可持久化 tab 顺序状态可交换，未移植，是与原版的唯一行为差异。

实现关键：`tab-line-format' 按 `(tabs buffer-name hscroll selected modified)' 缓存渲染结果，
这个缓存键不含 `tab-line-tab-name-function' 本身，所以单纯 let 绑定它、不主动清缓存的话
新标签不会显示。这里用 `tab-line-force-update' 在覆写前后各清一次缓存：
覆写前清一次让本轮字母标签能画出来；恢复原函数后再清一次，避免字母标签残留到下次显示。"
  (interactive "P")
  (let* ((bufs (my/tab-line--group-buffers))
         (label-alist (seq-mapn #'cons my/tab-line-ace-jump-keys bufs)))
    (if (null label-alist)
        (message "当前分组没有 tab 可跳转")
      (let ((orig tab-line-tab-name-function)
            key target)
        (unwind-protect
            (let ((tab-line-tab-name-function
                   (lambda (buf &optional buffers)
                     (let ((cell (rassq buf label-alist)))
                       (if cell
                           (concat "[" (char-to-string (car cell)) "] "
                                   (funcall orig buf buffers))
                         (funcall orig buf buffers))))))
              (tab-line-force-update nil)
              (setq key (read-char
                         (format "跳转到 tab [%s]: "
                                 (mapconcat (lambda (c) (char-to-string (car c)))
                                            label-alist " ")))))
          ;; 此处 tab-line-tab-name-function 已随上面的 let 退出而自动恢复
          ;; （无论正常返回还是 C-g 之类的非局部退出，动态绑定都会先解开，
          ;; 再轮到 unwind-protect 的清理表达式），所以这里清缓存用的是原始渲染函数。
          (tab-line-force-update nil))
        (setq target (cdr (assq key label-alist)))
        (cond
         ((null target) (message "无对应 tab: %c" key))
         ((equal arg '(16)) (kill-buffer target))
         (t (tab-line-select-tab-buffer target (selected-window))))))))

(progn
  (setq tab-line-tabs-function 'tab-line-tabs-buffer-groups)
  (setq tab-line-tabs-buffer-group-function #'my/tab-line-buffer-group-by-project)
  (setq tab-line-tab-name-function #'my/tab-line-tab-name)
  (setq tab-line-tab-name-format-function #'my/tab-line-tab-name-format)
  (setq tab-line-close-button-show t)      ; 每个标签都显关闭按钮（× ），像 centaur-tabs
  (setq tab-line-separator " ")            ; 相邻标签间留一丝缝
  (advice-add 'tab-line-tabs-buffer-list :filter-return #'my/tab-line-filter))

(add-hook 'first-change-hook #'my/tab-line-refresh)
(add-hook 'after-save-hook   #'my/tab-line-refresh)

(add-hook 'after-init-hook 'global-tab-line-mode)

;; ---- consult-buffer 里的「切换 tab 分组」源：narrow 键 ?g ----
;; 对应 centaur-tabs 时代最终版本的 my-consult--source-centaur-groups
;; （centaur-tabs-get-groups 枚举 + centaur-tabs-switch-group 动作）。
;; 原生机制：`tab-line-tabs-buffer-groups' 优先看 window-parameter `tab-line-group'；
;; 一旦当前 buffer 本身就属于该分组，它会自动清掉这个覆盖、回到「跟随当前 buffer」
;; 的默认状态，不需要手动复位——所以这里只需要设一次 window-parameter 就够了。
(defun my/tab-line--group-names ()
  "当前所有 tab-line 分组名（按字母序去重），供 consult `?g' 源枚举。"
  (seq-sort #'string<
            (seq-uniq
             (mapcar #'my/tab-line-buffer-group-by-project
                     (funcall tab-line-tabs-buffer-list-function)))))

(defun my/tab-line-switch-group (group)
  "把当前窗口的 tab-line 切到 GROUP 分组视图，不改变当前 buffer。"
  (set-window-parameter nil 'tab-line-group group)
  (tab-line-force-update nil))

(defvar my/consult--source-tab-line-group
  `( :name     "Tab Group"
     :narrow   ?g
     :items    ,#'my/tab-line--group-names
     :action   ,#'my/tab-line-switch-group)
  "consult-buffer 的 tab-line 分组切换源。")

(with-eval-after-load 'consult
  (add-to-list 'consult-buffer-sources 'my/consult--source-tab-line-group 'append))

(provide 'init-tab-line)
