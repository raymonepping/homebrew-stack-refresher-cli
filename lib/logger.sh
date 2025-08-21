log_title()    { echo -e "\n🧠 \e[1m$1\e[0m"; }
log_info()     { echo "➜ $1"; }
log_success()  { echo "✅ $1"; }
log_skip()     { echo "⏭️  $1"; }
log_error()    { echo "❌ $1" >&2; }
