;; extensions/tab-line/tab-line.el 	-*- lexical-binding: t -*-
;;
;; tab-line 实现本体，由 `lisp/init-bars.el' `load'。原生 tab-line（按项目分组 +
;; 过滤 eglot buffer），替代 centaur-tabs，零第三方、零启动开销。两条 bar（mode-line +
;; tab-line）字号/内边距统一逻辑留在 `init-bars.el' 里，这个文件只管 tab-line 本身。
;; 标签不带图标（跟 mode-line 一样走纯文字，简约优先），故不依赖 nerd-icons。
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
  "Group buffers by project root via project.el.
返回值首尾各带一个空格：`tab-line-separator' 现在是空串（标签之间紧挨着，见下面
setup 那段），但分组名（如 \".emacs.d\"）跟左边的 bar 边缘、右边第一个标签之间
都还需要一点视觉间隔，不然会跟边缘/标签糊在一起分不清——只加尾部空格时左边缘
贴得死死的，看起来像少了左 padding。这两个空格直接是分组名字符串的一部分，会
跟着 `tab-line-tab-group' 的背景色一起渲染（原理同标签自己的
`my/tab-line-tab-padding'：文本里的字符必然跟着所在标签共享同一个容器 face，
颜色不会错）。
⚠ 这个返回值同时也是分组的\"身份\"标识——`my/tab-line--group-buffers' 等函数用
`equal' 比较它来判断两个 buffer 是否同组，首尾空格对所有 buffer 一视同仁地加，
比较结果不受影响，不用担心带来分组错乱。"
  (with-current-buffer (or buffer (current-buffer))
    (let* ((dir (or (buffer-file-name) nil))
           (proj (project-current nil dir))
           (root (when proj (project-root proj))))
      (concat " "
              (if (and root dir)
                  (file-name-nondirectory (directory-file-name root))
                "Other")
              " "))))

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

;; ---- 标签文本：左右 padding + buffer 名 + 修改标记（不带图标，简约优先）----
(defconst my/tab-line-tab-padding " "
  "每个标签左右各留的字面空格 padding。用文本字符撑，而不是 face 的 `:box'
水平 line-width——实测 tab-line 下 `:box' 的水平 line-width 不会用 `:color' 真正
填充那片区域，会透出整条 tab-line bar 自己的背景色，达不到\"padding 属于标签
自己\"的效果（同样的 `:box' 用在垂直方向撑上下 padding 则没这个问题，见
`lisp/init-bars.el' 的 `my-ui--v-box'）。字面空格必然跟标签名共享同一个容器
face（由 `tab-line-tab-name-format-default' 统一 propertize/套用），颜色不会错，
是更可靠的写法。
选中/未选中标签统一用这一个值，不做宽度上的区分——\"当前调用是否在渲染选中
标签\"这个判断在更下游的 `tab-line-tab-name-format-default' 里（依赖 window 而
非单纯 buffer），要在这里复现同样判断只为了让选中标签的 padding 宽一点，不值得
为宽度差异专门搭一份逻辑；选中态靠颜色块 + 加粗已经足够醒目，见 `init-bars.el'
的 `my-ui-setup-bars'。")

(defun my/tab-line-tab-name (buffer &optional _buffers)
  "tab 标签文本：左右 padding + buffer 名 +（文件改动未存时）● 标记。
覆写 `tab-line-tab-name-function'。截断仍由 `tab-line-tab-name-truncated-max' 处理。"
  (concat my/tab-line-tab-padding
          (buffer-name buffer)
          (and (buffer-local-value 'buffer-file-name buffer)
               (buffer-modified-p buffer)
               " ●")
          my/tab-line-tab-padding))

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
  (setq tab-line-close-button-show nil)    ; 不显关闭按钮，标签只留文字，更简约
  ;; 不留分隔符：标签之间紧挨着，边界靠每个标签自己的背景块（选中/未选中/分组名
  ;; 各自不同深浅，见 init-bars.el）和标签自带的 `my/tab-line-tab-padding' 表达，
  ;; 不再额外插入分隔空白。
  (setq tab-line-separator "")
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
