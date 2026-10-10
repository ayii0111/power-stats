#!/bin/zsh

# 別名 mac_stats: 取得 Mac 當下電量與電池溫度
# 資料來源：ioreg AppleSmartBattery（不需 sudo）
# 選項：
#   -j  以 JSON 輸出（給程式／mod 讀取）
#   預設輸出一行精簡文字，例：🔋89% 放電中 · 🌡30.9°C

main() {
  local opt=''
  local out_json=0
  while getopts 'j' opt; do
    case $opt in
      j) out_json=1 ;;
      *) echo "Usage: mac_stats [-j]" >&2 && return 1 ;;
    esac
  done

  local raw=''
  raw=$(command ioreg -rn AppleSmartBattery) || return 1
  ! [[ $raw ]] && echo "Error: 找不到電池資訊（非筆電？）" >&2 && return 1

  local percent=$(read_key CurrentCapacity "$raw")
  local temp_raw=$(read_key Temperature "$raw")
  local is_charging=$(read_key IsCharging "$raw")
  local is_plugged=$(read_key ExternalConnected "$raw")

  # Temperature 單位為 0.01°C
  local temp_c=$(command gawk -v t=$temp_raw 'BEGIN { printf "%.1f", t / 100 }')

  local state='discharging'
  [[ $is_plugged == Yes ]] && state='plugged'
  [[ $is_charging == Yes ]] && state='charging'

  if (( $out_json )); then
    printf '{"battery":%d,"state":"%s","temp_c":%s}\n' $percent $state $temp_c
  else
    local state_zh='放電中'
    [[ $state == plugged ]] && state_zh='已接電源'
    [[ $state == charging ]] && state_zh='充電中'
    printf '🔋%d%% %s · 🌡%s°C\n' $percent $state_zh $temp_c
  fi
  return 0
}

function read_key() {
  # 只取頂層 "Key" = value 的行，避開 BatteryData 內同名欄位
  print -r -- "$2" | command gawk -v k="\"$1\"" '$1 == k && $2 == "=" { print $3; exit }'
}

main "$@"
_status=$?
unfunction main read_key
return $_status
