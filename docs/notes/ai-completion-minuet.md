# AI 补全（minuet + SiliconFlow）

`lisp/init-ai.el`（当前在 `init.el` 末尾注释停用）用 [minuet] 接 SiliconFlow 的 OpenAI 兼容接口。

## 关键点

- provider：`openai-compatible`，endpoint 指向 `https://api.siliconflow.cn/v1/chat/completions`。
- model：`Qwen/Qwen2.5-Coder-7B-Instruct`。
- **密钥不硬编码**：`:api-key` 传的是**环境变量名字符串** `"SILICONFLOW_API_KEY"`，minuet 内部 `getenv` 读取。

## 启用前

设环境变量（由用户在自己的 shell / 系统环境设置，不写进配置）：

```powershell
$env:SILICONFLOW_API_KEY = "sk-xxxx"
```

然后在 `init.el` 末尾取消 `(require 'init-ai)` 的注释。

## 注意

- 切勿把真实密钥写进任何入库文件（历史上曾硬编码过，已改为环境变量，见 git 记录）。
- minuet 在 `prog-mode` 下自动建议；节流/防抖参数在 `init-ai.el` 里可调以控成本/限流。

[minuet]: https://github.com/milanglacier/minuet-ai.el
