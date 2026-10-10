# power-stats

用手機透過 `claude remote-control` 對話時，在每輪回覆最後附上一行 Mac 的電量與電池溫度：

```
🔋 100% → 98% · 🌡  30.8 → 31.2°C
```

箭頭左邊是送出 prompt 當下的數值，右邊是 AI 停止回覆時的數值。終端機等非手機 session 不受影響。

另外，session 的第一個 prompt 送出後，回覆會先以一則訊息顯示當下數值，再處理請求：

```
🔋 98% · 🌡  30.6°C
```

## 安裝

```
claude plugin marketplace add ayii0111/custom-tools
claude plugin install power-stats@custom-tools
```

開發時可改用本機資料夾作為 marketplace（`claude plugin marketplace add ~/cc-projects/power-stats`、`claude plugin install power-stats@power-stats`），Claude Code 會直接讀取此資料夾；修改後執行 `/reload-plugins` 即可。
已開著的手機 session 不會套用，需從手機開新對話。

## 運作方式

1. `UserPromptSubmit` hook（`power_hook.zsh submit`）：讀取數值，存到 `$TMPDIR/power-stats/<session_id>`。若該檔原本不存在（session 的第一個 prompt），另以 `additionalContext` 請模型先原樣輸出當下數值。
2. `Stop` hook（`power_hook.zsh stop`）：再讀一次數值組成一行，回傳 `decision: block`，請模型把這一行原樣輸出成本輪最後一則訊息。
3. 再次停止時 `stop_hook_active` 為 true，hook 放行，不會無限循環。

只在 `CLAUDE_CODE_ENVIRONMENT_KIND=bridge`（remote-control 開出的 session）時作用。

為何要讓模型輸出：手機端只顯示模型的回覆；mod 的介面繪製與 Stop hook 的 `systemMessage` 在手機上都看不到。

## 檔案

| 檔案 | 作用 |
|---|---|
| `scripts/mac_stats.zsh` | 讀 `ioreg` AppleSmartBattery（不需 sudo）；`-j` 輸出 JSON |
| `scripts/power_hook.zsh` | hook 本體，`submit` / `stop` 兩種模式 |
| `hooks/hooks.json` | 掛上兩個 hook |

## 需求

macOS 筆電、`jq`、`gawk`（Homebrew）。

## 代價

手機上每輪多一次很短的模型回覆（少量 token、慢一兩秒）；該行會留在對話紀錄中。
