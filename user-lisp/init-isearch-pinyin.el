;;; init-isearch-pinyin.el --- isearch 支持拼音首字母搜中文  -*- lexical-binding: t; -*-

(defconst iys/isearch-pinyin-min-length 1
  "至少几个字母才做拼音展开。
⚠ 默认 1：展开后的正则是字面搜索的超集，从第一个字母就转，isearch 的锚点
（`isearch-other-end'）才不会落在字面字母上、把前面更早的中文匹配跳过去。")

(defvar iys/isearch-pinyin--cache '("" . nil)
  "STRING 到正则的最近一次结果。
isearch 每个按键会调多次搜索（主搜索 + 懒高亮分块），缓存省重复构造。")

(defun iys/isearch-pinyin--regexp (string)
  "STRING 是纯小写 ASCII 字母且够长时返回拼音首字母正则，否则 nil。
⚠ 大写不转：pinyinlib 的字符表只覆盖小写，且大写通常表示要精确匹配。"
  (if (equal string (car iys/isearch-pinyin--cache))
      (cdr iys/isearch-pinyin--cache)
    (setq iys/isearch-pinyin--cache
          (cons string
                (when (and (>= (length string) iys/isearch-pinyin-min-length)
                           (string-match-p "\\`[a-z]+\\'" string))
                  (require 'pinyinlib)
                  (pinyinlib-build-regexp-string string t))))
    (cdr iys/isearch-pinyin--cache)))

(defun iys/isearch-pinyin--search-fun ()
  "isearch 的搜索函数：纯小写字母按拼音首字母展开，其余走默认实现。
⚠ 正则搜索与 `isearch-regexp-function'（词/符号搜索）一律不转。"
  (lambda (string &optional bound noerror count)
    (let ((re (and (not isearch-regexp)
                   (null isearch-regexp-function)
                   (iys/isearch-pinyin--regexp string))))
      (if re
          (funcall (if isearch-forward #'re-search-forward #'re-search-backward)
                   re bound noerror count)
        (funcall (isearch-search-fun-default) string bound noerror count)))))

(define-minor-mode iys/isearch-pinyin-mode
  "在 isearch 里把纯小写字母当拼音首字母匹配中文，例如 `zw' 搜「中文」。
只影响 `C-s' / `C-r'，不动 evil 的 `/` `?' 和 `f' `t'；`M-r' 切正则搜索即绕过。"
  :global t
  :group 'editing
  (setq isearch-search-fun-function
        (and iys/isearch-pinyin-mode #'iys/isearch-pinyin--search-fun)))

(iys/isearch-pinyin-mode 1)

(provide 'init-isearch-pinyin)
