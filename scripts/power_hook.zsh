#!/bin/zsh

# 別名 power_hook: remote-control（手機）session 的電量溫度回報 hook
# 只在 CLAUDE_CODE_ENVIRONMENT_KIND=bridge 時作用，其餘 session 什麼都不做
# 用法（由 settings hooks 呼叫，stdin 為 hook 的 JSON 輸入）：
#   power_hook.zsh submit  UserPromptSubmit：記下送出時的數值
#   power_hook.zsh stop    Stop：取結束時數值，擋下一次停止，請模型原樣輸出一行

main() {
  local mode=${1-}
  local input=$(command cat)
  [[ $CLAUDE_CODE_ENVIRONMENT_KIND != bridge ]] && return 0

  local session_id=$(print -r -- "$input" | command jq -r '.session_id // "unknown"')
  local state_dir=${TMPDIR:-/tmp}/power-stats
  local start_file=$state_dir/$session_id
  local stats_cmd=${0:A:h}/mac_stats.zsh

  case $mode in
    submit)
      command mkdir -p $state_dir
      $stats_cmd -j > $start_file 2>/dev/null || : > $start_file
      ;;
    stop)
      # 模型已因本 hook 續寫過一次：放行，避免無限迴圈
      [[ $(print -r -- "$input" | command jq -r '.stop_hook_active') == true ]] && return 0
      local start='{}'
      [[ -s $start_file ]] && start=$(command cat $start_file)
      local end=$($stats_cmd -j 2>/dev/null)
      [[ $end ]] || end='{}'
      # 例：🔋 100% → 98% · 🌡  30.8 → 31.2°C；缺值以 ? 代替
      local line=$(command jq -rn --argjson s "$start" --argjson e "$end" '
        def v(x): if x == null then "?" else (x | tostring) end;
        "🔋 \(v($s.battery))% → \(v($e.battery))% · 🌡  \(v($s.temp_c)) → \(v($e.temp_c))°C"')
      local reason="【電量回報】不要做任何其他事，也不要加任何說明，只把下面這一行原樣輸出成本輪最後一則訊息：
$line"
      command jq -n --arg r "$reason" '{decision: "block", reason: $r}'
      ;;
    *)
      echo "Usage: power_hook {submit|stop}" >&2 && return 1
      ;;
  esac
  return 0
}

main "$@"
_status=$?
unfunction main
return $_status
