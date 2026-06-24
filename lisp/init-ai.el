(use-package minuet
  :ensure t
  :init
  ;; if you want to enable auto suggestion.
  ;; Note wthat you can manually invoke completions without enable minuet-auto-suggestion-mode
  (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  (add-hook 'minuet-active-mode-hook #'evil-normalize-keymaps)
  :config
  (setq minuet-provider 'openai-compatible)
  ;; (setq minuet-provider 'openai-fim-compatible)
  (setq minuet-request-timeout 2.5)
  (setq minuet-auto-suggestion-throttle-delay 1.5) ;; Increase to reduce costs and avoid rate limits
  (setq minuet-auto-suggestion-debounce-delay 0.6) ;; Increase to reduce costs and avoid rate limits


  ;; (plist-put minuet-openai-compatible-options :end-point "https://open.bigmodel.cn/api/paas/v4/chat/completions")
  (plist-put minuet-openai-compatible-options :end-point "https://api.siliconflow.cn/v1/chat/completions")
  ;; :api-key 传环境变量名（字符串），minuet 会用 getenv 读取，避免把密钥写进配置。
  ;; 使用前先设置环境变量，例如：export SILICONFLOW_API_KEY=sk-xxxx
  (plist-put minuet-openai-compatible-options :api-key "SILICONFLOW_API_KEY")
  (plist-put minuet-openai-compatible-options :model "Qwen/Qwen2.5-Coder-7B-Instruct")

  ;; Prioritize throughput for faster completion
  (minuet-set-optional-options minuet-openai-compatible-options :provider '(:sort "throughput"))
  (minuet-set-optional-options minuet-openai-compatible-options :max_tokens 56)
  (minuet-set-optional-options minuet-openai-compatible-options :top_p 0.9))

(provide 'init-ai)
