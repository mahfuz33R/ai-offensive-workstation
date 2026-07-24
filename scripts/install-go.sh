#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="go"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

GO_VERSION="${GO_VERSION:-1.26.5}"

install_go_runtime() {
  local arch archive url
  arch="$(detect_arch)"
  archive="go${GO_VERSION}.linux-${arch}.tar.gz"
  url="https://go.dev/dl/${archive}"
  retry curl -fsSL -o "/tmp/${archive}" "$url"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "/tmp/${archive}"
  rm -f "/tmp/${archive}"
  go version
  printf 'go\truntime\t%s\t%s\t%s\n' "$url" "$GO_VERSION" "/usr/local/go/bin/go" >> "$RESOLVED_FILE"
}

install_step "Go ${GO_VERSION}" "runtime" install_go_runtime

GO_TOOLS=(
  "subfinder|github.com/projectdiscovery/subfinder/v2/cmd/subfinder|subfinder"
  "assetfinder|github.com/tomnomnom/assetfinder|assetfinder"
  "github-subdomains|github.com/gwen001/github-subdomains|github-subdomains"
  "amass|github.com/owasp-amass/amass/v4/...|amass"
  "mapcidr|github.com/projectdiscovery/mapcidr/cmd/mapcidr|mapcidr"
  "chaos|github.com/projectdiscovery/chaos-client/cmd/chaos|chaos"
  "gotator|github.com/Josue87/gotator|gotator"
  "cero|github.com/glebarez/cero|cero"
  "galer|github.com/dwisiswant0/galer|galer"
  "dnsx|github.com/projectdiscovery/dnsx/cmd/dnsx|dnsx"
  "puredns|github.com/d3mondev/puredns/v2|puredns"
  "shuffledns|github.com/projectdiscovery/shuffledns/cmd/shuffledns|shuffledns"
  "gowitness|github.com/sensepost/gowitness|gowitness"
  "httprobe|github.com/tomnomnom/httprobe|httprobe"
  "httpx|github.com/projectdiscovery/httpx/cmd/httpx|httpx"
  "subjack|github.com/haccer/subjack|subjack"
  "notify|github.com/projectdiscovery/notify/cmd/notify|notify"
  "tok|github.com/mrco24/tok|tok"
  "gau|github.com/lc/gau/v2/cmd/gau|gau"
  "anti-burl|github.com/tomnomnom/hacks/anti-burl|anti-burl"
  "unfurl|github.com/tomnomnom/unfurl|unfurl"
  "anew|github.com/tomnomnom/anew|anew"
  "subzy|github.com/PentestPad/subzy|subzy"
  "SubOver|github.com/Ice3man543/SubOver|SubOver"
  "gron|github.com/tomnomnom/gron|gron"
  "qsreplace|github.com/tomnomnom/qsreplace|qsreplace"
  "cf-check|github.com/dwisiswant0/cf-check|cf-check"
  "gospider|github.com/jaeles-project/gospider|gospider"
  "hakrawler|github.com/hakluke/hakrawler|hakrawler"
  "waybackurls|github.com/tomnomnom/waybackurls|waybackurls"
  "gauplus|github.com/bp0lr/gauplus|gauplus"
  "katana|github.com/projectdiscovery/katana/cmd/katana|katana"
  "parameters|github.com/mrco24/parameters|parameters"
  "gf|github.com/tomnomnom/gf|gf"
  "freq|github.com/takshal/freq|freq"
  "web-archive|github.com/mrco24/web-archive|web-archive"
  "otx-url|github.com/mrco24/otx-url|otx-url"
  "dalfox|github.com/hahwul/dalfox/v2|dalfox"
  "kxss|github.com/Emoe/kxss|kxss"
  "Gxss|github.com/KathanP19/Gxss|Gxss"
  "Jeeves|github.com/ferreiraklet/Jeeves|Jeeves"
  "time-sql|github.com/mrco24/time-sql|time-sql"
  "mrco24-error-sql|github.com/mrco24/mrco24-error-sql|mrco24-error-sql"
  "subjs|github.com/lc/subjs|subjs"
  "getJS|github.com/003random/getJS/v2|getJS"
  "mantra|github.com/brosck/mantra|mantra"
  "nuclei|github.com/projectdiscovery/nuclei/v3/cmd/nuclei|nuclei"
  "cent|github.com/xm1k3/cent|cent"
  "jaeles|github.com/jaeles-project/jaeles|jaeles"
  "afrog|github.com/zan8in/afrog/v3/cmd/afrog|afrog"
  "mrco24-lfi|github.com/mrco24/mrco24-lfi|mrco24-lfi"
  "open-redirect|github.com/mrco24/open-redirect|open-redirect"
  "interactsh-client|github.com/projectdiscovery/interactsh/cmd/interactsh-client|interactsh-client"
  "ffuf|github.com/ffuf/ffuf/v2|ffuf"
  "gobuster|github.com/OJ/gobuster/v3|gobuster"
  "naabu|github.com/projectdiscovery/naabu/v2/cmd/naabu|naabu"
  "webanalyze|github.com/rverton/webanalyze/cmd/webanalyze|webanalyze"
)

GO_COMMANDS=()
for spec in "${GO_TOOLS[@]}"; do
  IFS='|' read -r name module binary <<<"$spec"
  install_step "$name" "go" go_tool "$name" "$module" "$binary"
  GO_COMMANDS+=("$name")
done

install_step "Go command smoke tests" "offline --help" \
  smoke_help_commands "${GO_COMMANDS[@]}"

finish_installer
