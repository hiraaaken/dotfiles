#!/bin/sh
# Claude Code statusline: 最大5行構成
#   1行目: 📁 <dir last2>  🌿 (<git branch>)
#   2行目: 🤖 <model>  <effort emoji> <effort level>（reasoning effortが取得できた場合のみ表示）
#   3行目: 📊 ctx [context usage bar] <pct>% <marker>
#   4行目: 🪙 <tokens>k tok · 💰 $<cost>
#   5行目: ⏳ 5h [bar]<pct>% <marker>  🗓️ 7d [bar]<pct>% <marker>（rate_limitsが取得できた場合のみ表示）
# 使用率はプログレスバー（▓=使用済み/░=未使用）と数値%で表現する。
# 文字色は使用率に応じて 緑<50(余裕あり) / 黄<80(警告) / 赤>=80(逼迫) で変化させるが、
# 状態ランプ的な丸絵文字（🟢🟡🔴等）は使わず、50%以上で▲・80%以上で⚠を数値%の直後に
# 付与することで記号自体でも警戒度を表現する。
# reasoning effort（low/medium/high/xhigh/max）が取得できた場合のみ表示。
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
tok=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) / 1000) | round')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty | floor')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Git branch（任意ロックは取得しない）
branch=""
if GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# ディレクトリは末尾2階層のみ表示
dir=$(echo "$cwd" | awk -F'/' '{if(NF>=2) print $(NF-1)"/"$NF; else print $NF}')

# 使用率に応じた文字色（ANSIのみ、絵文字ランプは使わない）を返す（$1: パーセント） 余裕あり<50緑 / 警告<80黄 / 逼迫>=80赤
indicator_color() {
  p="$1"
  if [ "$p" -ge 80 ]; then
    echo "\033[31m"
  elif [ "$p" -ge 50 ]; then
    echo "\033[33m"
  else
    echo "\033[32m"
  fi
}

# 使用率に応じた記号マーカーを返す（$1: パーセント） 余裕あり<50は付与なし / 警告<80は▲ / 逼迫>=80は⚠
# 丸い色絵文字（🟢🟡🔴等）の代わりに、意味のある記号の変化で警戒度を表現する。
indicator_marker() {
  p="$1"
  if [ "$p" -ge 80 ]; then
    echo "⚠"
  elif [ "$p" -ge 50 ]; then
    echo "▲"
  else
    echo ""
  fi
}

# 10文字のプログレスバーを生成（$1: パーセント、四捨五入し 0..10 にクランプ）
make_bar() {
  p="$1"
  filled=$(( (p + 5) / 10 ))
  [ "$filled" -lt 0 ] && filled=0
  [ "$filled" -gt 10 ] && filled=10
  bar=""
  i=0
  while [ "$i" -lt 10 ]; do
    if [ "$i" -lt "$filled" ]; then bar="${bar}▓"; else bar="${bar}░"; fi
    i=$((i + 1))
  done
  echo "$bar"
}

ctx_color=$(indicator_color "$pct")
ctx_bar=$(make_bar "$pct")
ctx_marker=$(indicator_marker "$pct")
ctx_marker_seg=""
[ -n "$ctx_marker" ] && ctx_marker_seg=" ${ctx_marker}"

# reasoning effort レベルに応じた絵文字（低いほど🐢、高いほど🔥）
eff_seg=""
if [ -n "$effort" ]; then
  case "$effort" in
    low) eff_icon="🐢" ;;
    medium) eff_icon="🚶" ;;
    high) eff_icon="🏃" ;;
    xhigh) eff_icon="⚡" ;;
    max) eff_icon="🔥" ;;
    *) eff_icon="🧠" ;;
  esac
  eff_seg="  \033[2m${eff_icon} ${effort}\033[0m"
fi

# 1行目: dir（青） + branch（緑）
if [ -n "$branch" ]; then
  printf "\033[34m📁 %s\033[0m \033[32m🌿 %s\033[0m\n" "$dir" "$branch"
else
  printf "\033[34m📁 %s\033[0m\n" "$dir"
fi

# 2行目: model（紫） + effort（淡色）
# eff_seg 自体に \033 エスケープを含むため printf の引数(%s)ではなくフォーマット文字列に直接埋め込む
# （effort レベルは low/medium/high/xhigh/max の固定語のみなので % が混入する心配はない）
printf "\033[35m🤖 %s\033[0m${eff_seg}\n" "$model"

# 3行目: コンテキスト使用率（ラベル + 色分けバー + pct + 警戒度マーカー、淡色）
printf "📊 ctx ${ctx_color}[%s]\033[0m \033[2m%s%%%s\033[0m\n" "$ctx_bar" "$pct" "$ctx_marker_seg"

# 4行目: トークン数 + コスト（淡色）
printf "\033[2m🪙 %sk tok · 💰 \$%.2f\033[0m" "$tok" "$cost"

# 5行目: rate_limits（Claude.aiサブスクリプション利用率）を色分けバー付きで表示（取得できた場合のみ）
# 各セグメントは printf でレンダリング済みの文字列として保持し、最終出力では %s 引数として渡す
# （% を含む値をフォーマット文字列に直接埋め込むと printf の変換指定として誤解釈されるため）
five_seg=""
if [ -n "$five" ]; then
  five_color=$(indicator_color "$five")
  five_bar=$(make_bar "$five")
  five_marker=$(indicator_marker "$five")
  five_marker_seg=""
  [ -n "$five_marker" ] && five_marker_seg=" ${five_marker}"
  five_seg=$(printf "⏳ 5h ${five_color}[%s]\033[0m \033[2m%s%%%s\033[0m" "$five_bar" "$five" "$five_marker_seg")
fi

week_seg=""
if [ -n "$week" ]; then
  week_color=$(indicator_color "$week")
  week_bar=$(make_bar "$week")
  week_marker=$(indicator_marker "$week")
  week_marker_seg=""
  [ -n "$week_marker" ] && week_marker_seg=" ${week_marker}"
  week_seg=$(printf "🗓️ 7d ${week_color}[%s]\033[0m \033[2m%s%%%s\033[0m" "$week_bar" "$week" "$week_marker_seg")
fi

rate_seg="$five_seg"
if [ -n "$week_seg" ]; then
  [ -n "$rate_seg" ] && rate_seg="${rate_seg}  "
  rate_seg="${rate_seg}${week_seg}"
fi
if [ -n "$rate_seg" ]; then
  printf "\n%s" "$rate_seg"
fi
