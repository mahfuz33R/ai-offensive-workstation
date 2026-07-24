#!/usr/bin/env python3
"""Generate the inventory-backed Hermes pentesting knowledge library."""

from __future__ import annotations

import argparse
import re
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "scripts/tool-inventory.tsv"
SKILL_ROOT = ROOT / "Rules/offensive-workstation-pentesting"
RETRIEVED = date.today().isoformat()


def rows(kind: str):
    for raw in INVENTORY.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#"):
            continue
        row_kind, name, check = raw.split("\t")
        if row_kind == kind:
            yield name, check


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


PURPOSE_TEXT = r"""
hermes|Run the Hermes AI agent, configuration, diagnostics, chat, skills, and gateway workflows.
zsh|Use the workstation's default interactive shell with shared Oh My Zsh features, completion, history, aliases, and prompt customization.
go|Compile, test, inspect, and manage Go programs and Go-based security tools.
python|Run Python 3 programs and isolated automation scripts.
node|Run JavaScript programs with the Node.js runtime used by Hermes and browser automation.
npm|Install and inspect Node.js packages and command-line applications.
agent-browser|Drive the bundled headless Chromium browser for navigation, interaction, extraction, and screenshots.
cyberstrike|Delegate a bounded, authorized security task to the CyberStrike agent and preserve its structured session output.
rustc|Compile and inspect Rust source code.
cargo|Build, install, test, and inspect Rust packages.
git|Manage source history and inspect repositories during authorized code review.
curl|Send controlled HTTP requests and save response bodies and headers.
wget|Download files or mirror explicitly scoped web content.
jq|Query, transform, filter, and validate JSON output from other tools.
tmux|Keep long-running terminal sessions and scans organized and recoverable.
rg|Search text, source trees, logs, and collected output quickly with regular expressions.
nmap|Discover scoped hosts and services and perform controlled service/version enumeration.
masscan|Perform high-speed TCP port discovery with an explicitly conservative rate.
massdns|Resolve large DNS name lists using supplied resolvers.
tcpdump|Capture and inspect authorized network traffic for troubleshooting and evidence.
nc|Test TCP/UDP connectivity and exchange simple protocol data.
httpx|Probe HTTP services and collect status, title, technology, redirect, and response metadata.
sqlmap|Validate suspected SQL injection in an owned application using low-risk settings.
nikto|Check an owned web server for known dangerous files, defaults, and common misconfiguration.
wfuzz|Fuzz selected HTTP request locations with controlled wordlists and filters.
dirsearch|Discover files and directories on an authorized web application.
feroxbuster|Recursively discover web content using concurrent HTTP requests.
cmake|Configure and generate native builds required by source-installed tools.
subfinder|Enumerate passive subdomains from configured data sources.
assetfinder|Collect domains and subdomains related to a scoped root domain.
github-subdomains|Find subdomains exposed in GitHub code using an authorized API token.
amass|Map attack surface data through passive or controlled active DNS enumeration.
mapcidr|Expand, combine, filter, and summarize CIDR ranges and IP lists.
chaos|Query ProjectDiscovery Chaos data for authorized domain assets.
gotator|Generate candidate subdomain permutations from known names.
cero|Extract domain names from TLS certificates presented by scoped hosts.
galer|Collect URLs from indexed and archival sources for scoped targets.
dnsx|Resolve and validate DNS records with structured output.
puredns|Resolve and wildcard-filter large candidate subdomain lists.
shuffledns|Perform DNS brute force and resolution using MassDNS.
gowitness|Capture screenshots and HTTP metadata for scoped web services.
httprobe|Identify which supplied hosts respond over HTTP or HTTPS.
subjack|Check scoped subdomains for dangling service fingerprints that may indicate takeover risk.
notify|Send selected findings to a configured notification provider.
tok|Extract and normalize useful tokens from collected text or URL data.
gau|Collect known URLs for a domain from public archive and intelligence providers.
anti-burl|Normalize URL streams for reliable pipeline processing.
unfurl|Extract URL components such as domains, paths, keys, and values.
anew|Append only previously unseen lines to a persistent findings file.
subzy|Check scoped subdomains for service fingerprints associated with takeover conditions.
SubOver|Check a supplied subdomain list for potential takeover fingerprints.
gron|Flatten JSON into line-oriented assignments that are easy to search.
qsreplace|Replace query-string values while preserving URL structure.
cf-check|Classify whether supplied hosts appear to be protected by Cloudflare.
gospider|Crawl authorized websites and extract links, scripts, and endpoints.
hakrawler|Perform a lightweight crawl of scoped web applications.
waybackurls|Retrieve archived URLs associated with a scoped domain.
gauplus|Collect and deduplicate archived URLs with additional filtering controls.
katana|Crawl web applications, including JavaScript-aware endpoint discovery.
parameters|Extract or discover URL parameter candidates from collected data.
gf|Apply named JSON regex patterns to URL and text streams.
freq|Analyze recurring parameters or URL structures in collected reconnaissance data.
web-archive|Query web archives for historical URLs belonging to a scoped domain.
otx-url|Collect URL intelligence from AlienVault OTX for a scoped domain.
dalfox|Analyze reflected parameters and validate XSS findings with controlled checks.
kxss|Identify reflected URL parameters that may require manual XSS review.
Gxss|Check URL reflection contexts to prioritize XSS testing.
Jeeves|Assist controlled SQL injection discovery and validation.
time-sql|Detect time-based SQL injection indicators with scoped requests.
mrco24-error-sql|Identify database error patterns in authorized HTTP responses.
subjs|Extract JavaScript file URLs from a URL stream.
getJS|Collect JavaScript resources referenced by a scoped application.
mantra|Search JavaScript and source text for endpoints, secrets, and interesting patterns.
nuclei|Run selected, reviewed templates against authorized targets and emit structured findings.
cent|Manage community Nuclei templates used by the workstation.
jaeles|Run signature-based web security checks against authorized URLs.
afrog|Run template-driven vulnerability checks and produce a reviewable report.
mrco24-lfi|Check scoped URL candidates for local-file-inclusion indicators.
open-redirect|Check URL parameters for controlled open-redirect behavior.
interactsh-client|Create and monitor interaction domains for authorized out-of-band verification.
ffuf|Fuzz web paths, parameters, headers, and virtual hosts with rate controls.
gobuster|Enumerate directories, DNS names, or virtual hosts using explicit wordlists.
naabu|Discover TCP ports on scoped hosts with conservative rate settings.
webanalyze|Fingerprint web technologies using the bundled application definitions.
shodan|Query Shodan for information about owned IP addresses and domains.
altdns|Generate and optionally resolve subdomain permutations.
certcrunchy|Collect certificate-transparency names related to a scoped domain.
ctfr|Enumerate certificate-transparency subdomains for a domain.
knockpy|Enumerate subdomains and DNS information for an authorized domain.
censys-subdomain-finder|Find subdomains using Censys certificate and host data.
censys|Query the Censys platform for owned hosts, certificates, and services.
dnsvalidator|Build and validate DNS resolver lists for enumeration workflows.
oralyzer|Check URL parameters for controlled open-redirect behavior.
interlace|Run a command template across scoped targets with bounded concurrency.
paramspider|Collect parameterized URLs associated with a scoped domain.
waymore|Collect archived URLs and optionally related response data.
xnLinkFinder|Extract endpoints, parameters, and links from web pages or JavaScript.
uro|Normalize and filter large URL lists to high-value candidates.
arjun|Discover hidden HTTP parameters with controlled requests.
xsstrike|Analyze reflected input and XSS contexts in an authorized application.
xss-vibes|Assist reflected-XSS discovery against explicitly scoped URLs.
linkfinder|Extract endpoints and links from JavaScript content.
nosqlmap|Assess an owned application for NoSQL injection conditions in a controlled lab workflow.
ghauri|Validate suspected SQL injection using controlled request levels.
droopescan|Identify Drupal, SilverStripe, and WordPress versions, plugins, and themes.
whatwaf|Identify web application firewall behavior for an authorized target.
secretfinder|Search JavaScript content for potentially sensitive strings and endpoints.
tplmap|Assess suspected server-side template injection in an isolated or owned application.
sstimap|Detect and validate server-side template injection in an explicitly authorized target.
GitDorker|Search GitHub code for exposure patterns using an authorized token and scoped queries.
gitGraber|Monitor or search GitHub content for configured sensitive-data patterns.
poc-bomber|Match vulnerability information to available proof-of-concept references for manual validation.
Injectus|Assist controlled testing of injection points in an authorized application.
OpenRedireX|Test a list of scoped URLs for open-redirect behavior using benign destinations.
ssrfmap|Validate a suspected SSRF parameter in a controlled environment using selected modules.
gopherus|Generate protocol-specific Gopher payloads for isolated SSRF lab validation.
wappalyzer-cli|Fingerprint technologies used by a scoped web page through the `wappy` command.
NtHiM|Check scoped domains for dangling DNS and service fingerprints that may indicate subdomain takeover risk.
wpscan|Assess an owned WordPress site for version, component, and configuration exposure.
whatweb|Identify web technologies, frameworks, servers, and embedded components.
findomain|Enumerate subdomains from passive data sources.
aquatone|Collect and visually organize screenshots of scoped HTTP services.
nrich|Enrich supplied IP addresses with public service and vulnerability context.
x8|Discover hidden HTTP parameters with configurable request behavior.
unimap|Scan scoped networks for open TCP ports and produce machine-readable results.
xray|Run reviewed XPOC rules against authorized targets.
lilly|Orchestrate reconnaissance steps from the Lilly shell toolkit.
JSScanner|Inspect JavaScript resources for endpoints and interesting content.
gitdumper|Download exposed Git repository objects from an owned web application for review.
extractor|Reconstruct a working tree from a previously collected Git object directory.
gitfinder|Check an authorized web target for an exposed `.git` directory.
gau-expose|Process archived URLs to identify potentially exposed files and endpoints.
kr|Enumerate API routes using Kiterunner route dictionaries.
findom-xss|Combine domain URL collection and reflection checks to prioritize XSS review.
sploitscan|Summarize CVE information, public exploit references, and remediation context.
aem-hacker|Assess an owned Adobe Experience Manager deployment for exposed endpoints.
go-earlybird|Scan source and files for secrets using EarlyBird detectors.
"""


def parse_mapping(text: str) -> dict[str, str]:
    result = {}
    for line in text.strip().splitlines():
        key, value = line.split("|", 1)
        result[key] = value
    return result


PURPOSES = parse_mapping(PURPOSE_TEXT)

SOURCE_OVERRIDES = {
    "hermes": "https://github.com/NousResearch/hermes-agent",
    "zsh": "https://zsh.sourceforge.io/Doc/",
    "go": "https://go.dev/doc/",
    "python": "https://docs.python.org/3/",
    "node": "https://nodejs.org/docs/latest/api/",
    "npm": "https://docs.npmjs.com/cli/",
    "agent-browser": "https://github.com/vercel-labs/agent-browser",
    "cyberstrike": "https://github.com/CyberStrikeus/CyberStrike",
    "rustc": "https://doc.rust-lang.org/rustc/",
    "cargo": "https://doc.rust-lang.org/cargo/",
    "git": "https://git-scm.com/docs",
    "curl": "https://curl.se/docs/",
    "wget": "https://www.gnu.org/software/wget/manual/wget.html",
    "jq": "https://jqlang.github.io/jq/manual/",
    "tmux": "https://github.com/tmux/tmux",
    "rg": "https://github.com/BurntSushi/ripgrep",
    "nmap": "https://nmap.org/book/man.html",
    "masscan": "https://github.com/robertdavidgraham/masscan",
    "massdns": "https://github.com/blechschmidt/massdns",
    "tcpdump": "https://www.tcpdump.org/manpages/tcpdump.1.html",
    "nc": "https://man.openbsd.org/nc",
    "sqlmap": "https://github.com/sqlmapproject/sqlmap/wiki",
    "nikto": "https://github.com/sullo/nikto",
    "wfuzz": "https://github.com/xmendez/wfuzz",
    "dirsearch": "https://github.com/maurosoria/dirsearch",
    "feroxbuster": "https://github.com/epi052/feroxbuster",
    "cmake": "https://cmake.org/documentation/",
    "shodan": "https://github.com/achillean/shodan-python",
    "altdns": "https://github.com/infosec-au/altdns",
    "certcrunchy": "https://github.com/joda32/CertCrunchy",
    "ctfr": "https://github.com/UnaPibaGeek/ctfr",
    "knockpy": "https://github.com/guelfoweb/knock",
    "censys-subdomain-finder": "https://github.com/christophetd/censys-subdomain-finder",
    "censys": "https://github.com/censys/censys-python",
    "dnsvalidator": "https://github.com/vortexau/dnsvalidator",
    "oralyzer": "https://github.com/r0075h3ll/Oralyzer",
    "interlace": "https://github.com/codingo/Interlace",
    "paramspider": "https://github.com/devanshbatham/ParamSpider",
    "waymore": "https://github.com/xnl-h4ck3r/waymore",
    "xnLinkFinder": "https://github.com/xnl-h4ck3r/xnLinkFinder",
    "uro": "https://github.com/s0md3v/uro",
    "arjun": "https://github.com/s0md3v/Arjun",
    "xsstrike": "https://github.com/s0md3v/XSStrike",
    "xss-vibes": "https://github.com/faiyazahmad07/xss_vibes",
    "linkfinder": "https://github.com/GerbenJavado/LinkFinder",
    "nosqlmap": "https://github.com/codingo/NoSQLMap",
    "ghauri": "https://github.com/r0oth3x49/ghauri",
    "droopescan": "https://github.com/droope/droopescan",
    "whatwaf": "https://github.com/Ekultek/WhatWaf",
    "secretfinder": "https://github.com/m4ll0k/SecretFinder",
    "tplmap": "https://github.com/epinna/tplmap",
    "sstimap": "https://github.com/vladko312/SSTImap",
    "GitDorker": "https://github.com/obheda12/GitDorker",
    "gitGraber": "https://github.com/hisxo/gitGraber",
    "poc-bomber": "https://github.com/tr0uble-mAker/POC-bomber",
    "Injectus": "https://github.com/dubs3c/Injectus",
    "OpenRedireX": "https://github.com/devanshbatham/OpenRedireX",
    "ssrfmap": "https://github.com/swisskyrepo/SSRFmap",
    "gopherus": "https://github.com/Antabuse-123/Gopherus",
    "wappalyzer-cli": "https://github.com/gokulapap/wappalyzer-cli",
    "NtHiM": "https://github.com/TheBinitGhimire/NtHiM",
    "wpscan": "https://github.com/wpscanteam/wpscan",
    "whatweb": "https://github.com/urbanadventurer/WhatWeb",
    "findomain": "https://github.com/Findomain/Findomain",
    "aquatone": "https://github.com/michenriksen/aquatone",
    "nrich": "https://gitlab.com/shodan-public/nrich",
    "x8": "https://github.com/Sh1Yo/x8",
    "unimap": "https://github.com/Edu4rdSHL/unimap",
    "xray": "https://github.com/chaitin/xray",
    "lilly": "https://github.com/Dheerajmadhukar/Lilly",
    "JSScanner": "https://github.com/dark-warlord14/JSScanner",
    "gitdumper": "https://github.com/internetwache/GitTools",
    "extractor": "https://github.com/internetwache/GitTools",
    "gitfinder": "https://github.com/internetwache/GitTools",
    "gau-expose": "https://github.com/tamimhasan404/Gau-Expose",
    "kr": "https://github.com/assetnote/kiterunner",
    "findom-xss": "https://github.com/dwisiswant0/findom-xss",
    "sploitscan": "https://github.com/xaitax/SploitScan",
    "aem-hacker": "https://github.com/0ang3el/aem-hacker",
    "go-earlybird": "https://github.com/americanexpress/earlybird",
}


CATEGORY_MEMBERS = {
    "platform-and-utilities": "hermes zsh go python node npm agent-browser rustc cargo git curl wget jq tmux rg cmake".split(),
    "network-mapping": "nmap masscan massdns tcpdump nc naabu unimap nrich".split(),
    "dns-and-subdomains": "subfinder assetfinder github-subdomains amass mapcidr chaos gotator cero dnsx puredns shuffledns subjack SubOver subzy findomain altdns certcrunchy ctfr knockpy censys-subdomain-finder dnsvalidator NtHiM".split(),
    "http-discovery": "httpx nikto wfuzz dirsearch feroxbuster gowitness httprobe ffuf gobuster webanalyze whatwaf wappalyzer-cli whatweb aquatone kr droopescan wpscan aem-hacker".split(),
    "url-js-and-content": "galer tok gau anti-burl unfurl anew gron qsreplace cf-check gospider hakrawler waybackurls gauplus katana parameters gf freq web-archive otx-url subjs getJS mantra paramspider waymore xnLinkFinder uro arjun linkfinder secretfinder JSScanner gau-expose".split(),
    "vulnerability-and-templates": "notify nuclei cent jaeles afrog interactsh-client xray sploitscan poc-bomber".split(),
    "xss-and-injection": "sqlmap dalfox kxss Gxss Jeeves time-sql mrco24-error-sql mrco24-lfi open-redirect xsstrike xss-vibes nosqlmap ghauri tplmap sstimap Injectus OpenRedireX ssrfmap gopherus oralyzer findom-xss".split(),
    "source-git-and-secrets": "GitDorker gitGraber lilly gitdumper extractor gitfinder go-earlybird".split(),
    "automation-and-reporting": "interlace censys shodan cyberstrike".split(),
}


def category_for(name: str) -> str:
    for category, members in CATEGORY_MEMBERS.items():
        if name in members:
            return category
    return "specialized-security"


def parse_go_sources() -> dict[str, str]:
    result = {}
    source = (ROOT / "scripts/install-go.sh").read_text(encoding="utf-8")
    for name, module in re.findall(
        r'^\s*"([^|"\n]+)\|([^|"\n]+)\|[^|"\n]+"', source, re.MULTILINE
    ):
        if module.startswith("github.com/"):
            parts = module.removesuffix("/...").split("/")
            repo_parts = parts[:3]
            result[name] = "https://" + "/".join(repo_parts)
    return result


SOURCES = {**parse_go_sources(), **SOURCE_OVERRIDES}


EXAMPLES = {
    "nmap": 'nmap -sV -T3 -oA "$OUTPUT_DIR/nmap-services" "$TARGET"',
    "masscan": 'masscan "$TARGET" -p80,443 --rate 100 -oJ "$OUTPUT_DIR/masscan.json"',
    "tcpdump": 'tcpdump -ni any -c 100 -w "$OUTPUT_DIR/capture.pcap" host "$TARGET"',
    "nc": 'nc -vz "$TARGET" 443',
    "httpx": 'httpx -u "$TARGET_URL" -status-code -title -tech-detect -json -o "$OUTPUT_DIR/httpx.jsonl"',
    "nikto": 'nikto -h "$TARGET_URL" -nocheck -Format json -output "$OUTPUT_DIR/nikto.json"',
    "dirsearch": 'dirsearch -u "$TARGET_URL" -w /opt/security-assets/wordlists/SecLists/Discovery/Web-Content/common.txt --format json -o "$OUTPUT_DIR/dirsearch.json"',
    "feroxbuster": 'feroxbuster -u "$TARGET_URL" -w /opt/security-assets/wordlists/SecLists/Discovery/Web-Content/common.txt --rate-limit 20 -o "$OUTPUT_DIR/feroxbuster.txt"',
    "subfinder": 'subfinder -d "$TARGET_DOMAIN" -silent -o "$OUTPUT_DIR/subfinder.txt"',
    "assetfinder": 'assetfinder --subs-only "$TARGET_DOMAIN" | anew "$OUTPUT_DIR/subdomains.txt"',
    "amass": 'amass enum -passive -d "$TARGET_DOMAIN" -o "$OUTPUT_DIR/amass.txt"',
    "dnsx": 'dnsx -l "$OUTPUT_DIR/subdomains.txt" -a -resp -json -o "$OUTPUT_DIR/dnsx.jsonl"',
    "httprobe": 'cat "$OUTPUT_DIR/subdomains.txt" | httprobe | anew "$OUTPUT_DIR/live-urls.txt"',
    "gau": 'gau --subs "$TARGET_DOMAIN" --o "$OUTPUT_DIR/gau-urls.txt"',
    "waybackurls": 'printf "%s\\n" "$TARGET_DOMAIN" | waybackurls > "$OUTPUT_DIR/wayback-urls.txt"',
    "katana": 'katana -u "$TARGET_URL" -d 3 -jc -jsonl -o "$OUTPUT_DIR/katana.jsonl"',
    "gf": 'cat "$OUTPUT_DIR/all-urls.txt" | gf xss > "$OUTPUT_DIR/xss-candidates.txt"',
    "dalfox": 'dalfox file "$OUTPUT_DIR/xss-candidates.txt" --silence --output "$OUTPUT_DIR/dalfox.txt"',
    "nuclei": 'nuclei -u "$TARGET_URL" -t /opt/security-assets/templates/nuclei-templates -rl 20 -jsonl -o "$OUTPUT_DIR/nuclei.jsonl"',
    "ffuf": 'ffuf -u "$TARGET_URL/FUZZ" -w /opt/security-assets/wordlists/SecLists/Discovery/Web-Content/common.txt -rate 20 -of json -o "$OUTPUT_DIR/ffuf.json"',
    "gobuster": 'gobuster dir -u "$TARGET_URL" -w /opt/security-assets/wordlists/SecLists/Discovery/Web-Content/common.txt -t 10 -o "$OUTPUT_DIR/gobuster.txt"',
    "naabu": 'naabu -host "$TARGET" -rate 100 -json -o "$OUTPUT_DIR/naabu.jsonl"',
    "sqlmap": 'sqlmap -u "$TARGET_URL" --batch --level 1 --risk 1 --output-dir "$OUTPUT_DIR/sqlmap"',
    "wpscan": 'wpscan --url "$TARGET_URL" --format json --output "$OUTPUT_DIR/wpscan.json"',
    "whatweb": 'whatweb --log-json "$OUTPUT_DIR/whatweb.json" "$TARGET_URL"',
    "shodan": 'shodan host "$TARGET" | tee "$OUTPUT_DIR/shodan-host.txt"',
    "censys": 'censys search "$TARGET" | tee "$OUTPUT_DIR/censys-search.txt"',
    "arjun": 'arjun -u "$TARGET_URL" -oJ "$OUTPUT_DIR/arjun.json"',
    "xsstrike": 'xsstrike -u "$TARGET_URL" --skip-dom',
    "linkfinder": 'linkfinder -i "$TARGET_URL" -o cli | tee "$OUTPUT_DIR/linkfinder.txt"',
    "sploitscan": 'sploitscan CVE-2024-0001 | tee "$OUTPUT_DIR/sploitscan.txt"',
    "gitfinder": 'gitfinder -i "$TARGET_URL" | tee "$OUTPUT_DIR/gitfinder.txt"',
    "go-earlybird": 'go-earlybird -path /workspace/projects | tee "$OUTPUT_DIR/earlybird.txt"',
    "jq": 'jq -c . "$OUTPUT_DIR/httpx.jsonl" > "$OUTPUT_DIR/httpx-normalized.jsonl"',
    "rg": 'rg -n -i "password|secret|token" /workspace/projects | tee "$OUTPUT_DIR/source-review.txt"',
    "curl": 'curl --fail-with-body --silent --show-error --dump-header "$OUTPUT_DIR/headers.txt" "$TARGET_URL" -o "$OUTPUT_DIR/body.html"',
    "cyberstrike": 'cyberstrike run --agent cyberstrike --format json --dir "$PROJECT_DIR" "$TASK" | tee "$OUTPUT_DIR/cyberstrike.jsonl"',
}

HELP_ARGS = {
    "go": "help",
    "git": "-h",
    "curl": "--help all",
    "tmux": "-h",
    "nmap": "-h",
    "massdns": "-h",
    "tcpdump": "--help",
    "nc": "-h",
    "nikto": "-Help",
    "JSScanner": "__NO_ARGS__",
    "cyberstrike": "--help",
}


OUTPUTS = {
    "platform-and-utilities": "Version, build, transformed data, session state, or command diagnostics depending on the utility.",
    "network-mapping": "Host, port, service, packet, or enrichment records. Prefer JSON/JSONL, PCAP, or normal output files when supported.",
    "dns-and-subdomains": "Domain names, DNS record answers, resolver status, wildcard decisions, or takeover fingerprints.",
    "http-discovery": "URLs, status codes, titles, technologies, discovered paths, screenshots, and response metadata.",
    "url-js-and-content": "Normalized URLs, parameters, JavaScript resources, endpoints, matched patterns, and crawl provenance.",
    "vulnerability-and-templates": "Candidate findings with template/signature IDs, severity, matcher evidence, affected location, and remediation context.",
    "xss-and-injection": "Candidates or validation evidence. Treat every result as unconfirmed until reproduced safely and manually reviewed.",
    "source-git-and-secrets": "File paths, commits, repository objects, matched strings, and detector identifiers. Redact genuine secrets immediately.",
    "automation-and-reporting": "Provider records, batch execution results, command output, and error summaries.",
    "specialized-security": "Tool-specific text or structured findings described by the captured installed-version help.",
}

IO_TYPES = {
    "platform-and-utilities": ("Arguments, source files, or piped data", "Diagnostics, transformed data, or build/session state"),
    "network-mapping": ("In-scope IPs/CIDRs, ports, or interfaces", "Hosts, services, packets, or enrichment records"),
    "dns-and-subdomains": ("In-scope domains, names, resolvers, or CIDRs", "Names, DNS answers, and validation status"),
    "http-discovery": ("Authorized URLs/hosts and reviewed wordlists", "HTTP metadata, paths, technologies, or screenshots"),
    "url-js-and-content": ("URLs, pages, JavaScript, JSON, or text streams", "Normalized URLs, endpoints, parameters, or pattern matches"),
    "vulnerability-and-templates": ("Authorized targets and reviewed templates/signatures", "Candidate findings and matcher evidence"),
    "xss-and-injection": ("Explicitly scoped URLs, parameters, or request files", "Candidates and controlled validation evidence"),
    "source-git-and-secrets": ("Owned repositories, files, or scoped GitHub queries", "Paths, commits, objects, or redacted matches"),
    "automation-and-reporting": ("Scoped targets, provider queries, or command templates", "Batch results, provider records, and errors"),
    "specialized-security": ("Tool-specific authorized input", "Tool-specific text or structured results"),
}


ALIASES = {}
compat = (ROOT / "scripts/install-compatibility.sh").read_text(encoding="utf-8")
for legacy, canonical in re.findall(r'^\s*"([^|"\n]+)\|([^|"\n]+)"\s*$', compat, re.MULTILINE):
    ALIASES[legacy] = canonical


WORKFLOWS = {
    "reconnaissance.md": """# Reconnaissance workflow

Start from a written scope. Use passive collection first (`subfinder`, `assetfinder`, `amass -passive`, `gau`, `waybackurls`), normalize with `anew`/`uro`, resolve with `dnsx`, and probe with `httpx`. Store every stage separately so provenance is preserved. Do not expand into related organizations or third-party infrastructure without written authorization.
""",
    "dns-subdomains.md": """# DNS and subdomain workflow

1. Put root domains in `$OUTPUT_DIR/roots.txt`.
2. Combine passive results from Subfinder, Assetfinder, Amass, certificate tools, Chaos, and approved provider APIs.
3. Use `anew` to deduplicate, `gotator` only for in-scope permutations, and `puredns`/`shuffledns` with a validated resolver list.
4. Use `dnsx` JSONL output to retain record evidence and separate wildcard results.
5. Manually verify any takeover fingerprint before reporting it.
""",
    "network-mapping.md": """# Network mapping workflow

Use Naabu, Nmap, or a low-rate Masscan pass only for CIDRs explicitly listed in scope. Begin with a small port set and conservative rate. Confirm discoveries with Nmap service detection. Use tcpdump when you need packet evidence or troubleshooting. Never run broad Internet ranges, spoofing, evasion, or denial-of-service modes.
""",
    "http-discovery.md": """# HTTP discovery workflow

Probe resolved hosts with HTTPX, fingerprint with WhatWeb/Webanalyze, capture representative screenshots with GoWitness or Aquatone, then perform bounded content discovery with Dirsearch, Feroxbuster, FFUF, Gobuster, or Kiterunner. Reuse one approved wordlist and low concurrency first; exclude logout, deletion, billing, and state-changing routes.
""",
    "content-fuzzing.md": """# Content and parameter fuzzing workflow

Confirm the base request manually, choose one insertion point, use a small reviewed wordlist, set a conservative request rate, and filter a known baseline response. FFUF, Wfuzz, Arjun, x8, and Kiterunner can create substantial traffic. Save structured output and manually reproduce interesting differences before reporting them.
""",
    "url-javascript.md": """# URL and JavaScript analysis workflow

Collect URLs with Gau, Waybackurls, Waymore, Katana, GoSpider, and Hakrawler. Normalize with Uro and `anew`. Extract JavaScript with `subjs`/getJS and analyze local copies with LinkFinder, SecretFinder, Mantra, JSScanner, and ripgrep. Treat archive URLs as historical leads, not proof that an endpoint still exists.
""",
    "template-scanning.md": """# Template scanner workflow

Review and pin the template directories used by Nuclei, Jaeles, Afrog, Cent, or Xray. Start with informational/low-risk templates and a low rate. Disable templates that perform intrusive actions. A template match is a candidate finding; preserve matcher evidence and reproduce it safely before assigning severity.
""",
    "cms-testing.md": """# CMS and platform workflow

Fingerprint first with WhatWeb/Webanalyze, then select the platform-specific tool: WPScan for WordPress, Droopescan for supported CMS products, or AEM Hacker for owned Adobe Experience Manager deployments. Prefer passive enumeration, avoid password attacks, and report component/version evidence with uncertainty where fingerprinting is heuristic.
""",
    "xss.md": """# XSS review workflow

Use GF, kxss, Gxss, and reflection-oriented tools to prioritize parameters. Use Dalfox or XSStrike only against approved test accounts and benign marker payloads. Do not target stored-XSS sinks that could affect other users. Record reflection context, encoding, browser reproduction steps, and the exact harmless proof used.
""",
    "injection.md": """# Injection review workflow

Begin from a manually observed parameter and baseline response. SQLmap/Ghauri, NoSQLMap, SSTImap/tplmap, SSRFmap, and related tools can become intrusive: use lowest level/risk, a single parameter, bounded timeouts, and an isolated test environment. Do not dump records, execute commands, read unrelated files, or create persistence.
""",
    "git-secrets.md": """# Git and secret review workflow

Use GitFinder before GitDumper and only download an exposed repository owned by the user. Reconstruct it offline with Extractor. Use EarlyBird, Mantra, GitDorker, gitGraber, and ripgrep for source review. Never print real secret values into reports; record type, file, line/commit, redacted fingerprint, validation status, and rotation recommendation.
""",
    "enrichment.md": """# Asset enrichment workflow

Use Shodan, Censys, Chaos, nrich, certificate data, and OTX only for assets already in scope. Provider data can be stale. Record query time and source, correlate against direct low-impact observations, and never treat an Internet intelligence record as proof of a current vulnerability.
""",
    "browser-screenshots.md": """# Browser and screenshot workflow

Use `agent-browser` for interactive headless navigation and GoWitness/Aquatone for batches. Use test accounts, avoid submitting state-changing forms, and store screenshots under the engagement report directory. Screenshots may contain personal or secret data; review and redact them before sharing.
""",
    "reporting-pipelines.md": """# Reporting and pipeline workflow

Create `/workspace/reports/$ENGAGEMENT/{raw,normalized,evidence,final}`. Keep original output immutable under `raw`, use jq/anew/Uro for normalized data, and place manually verified evidence separately. Every finding needs scope, timestamp, tool and resolved version, exact command with secrets removed, evidence, manual verification, impact, and remediation.
""",
    "cyberstrike-orchestration.md": """# CyberStrike orchestration workflow

Load [the CyberStrike knowledge router](../cyberstrike/INDEX.md) before delegation. Use the non-interactive `run` command with a pinned project directory, an engagement-specific deny-first permission policy, explicit target allowlists, and `--format json`. Do not use the TUI, session sharing, broad auto-approval, or guessed flags in Hermes automation. Save JSONL output under the engagement raw directory and manually verify every candidate finding.
""",
}


SAFETY = """# Authorized-use and safety rules

This library is for testing software and infrastructure the user owns or has explicit written authorization to assess.

1. Establish the exact domains, IP ranges, applications, accounts, time window, and prohibited actions before active testing.
2. Never infer authorization from public reachability, container privilege, a bug-bounty program name, or possession of a URL.
3. Begin passive and low-rate. Increase coverage only when the scope and service stability support it.
4. Do not perform denial of service, persistence, destructive modification, credential attacks, data extraction, lateral movement, or testing of third parties.
5. Prefer test accounts and harmless unique markers. Stop if unexpected sensitive data or production instability appears.
6. Keep credentials in runtime environment variables; never place them in commands, Markdown, manifests, or reports.
7. Save evidence under `/workspace/reports/$ENGAGEMENT` and redact secrets, tokens, cookies, and personal data before sharing.
8. A scanner result is a lead, not a confirmed vulnerability. Reproduce safely and document false-positive analysis.
"""


ASSETS = """# Installed assets

| Asset | Container path | Purpose |
|---|---|---|
| SecLists | `/opt/security-assets/wordlists/SecLists` | Curated discovery, fuzzing, DNS, and payload lists; select the smallest relevant list. |
| WordList | `/opt/security-assets/wordlists/WordList` | Additional community wordlists. |
| mrco24-wordlist | `/opt/security-assets/wordlists/mrco24-wordlist` | Wordlists used by the original workstation workflow. |
| Nuclei templates | `/opt/security-assets/templates/nuclei-templates` | Official ProjectDiscovery checks; review templates before execution. |
| Fuzzing templates | `/opt/security-assets/templates/fuzzing-templates` | ProjectDiscovery fuzzing definitions; potentially intrusive, so review and rate-limit. |
| Jaeles signatures | `/opt/security-assets/templates/jaeles-signatures` | Official Jaeles signatures. |
| GHsec Jaeles signatures | `/opt/security-assets/templates/ghsec-jaeles-signatures` | Additional community Jaeles signatures. |
| GF patterns | `/opt/security-assets/patterns/gf` | JSON regex patterns loaded by the workstation GF wrapper. |
| Kiterunner routes | `/opt/security-assets/wordlists/kiterunner` | API route dictionaries for `kr`. |
| LFI payloads | `/opt/security-assets/payloads/lfi_payloads.txt` | Controlled LFI candidate strings; use only in isolated or explicitly approved testing. |
| PayloadsAllTheThings | `/opt/security-assets/payloads/PayloadsAllTheThings` | Full local snapshot of PayloadsAllTheThings. Load only the vulnerability-specific subdirectory needed for an authorized test. |
| payload-box | `/opt/security-assets/payloads/payload-box` | Full local snapshot of payload-box payload lists. Use only reviewed files for approved testing. |
| Payload source index | `/opt/security-assets/payloads/payload-sources.tsv` | Installed payload source paths and upstream project references. |
| Payload file index | `/opt/security-assets/payloads/payload-repository-files.txt` | File-level index for quickly locating payload material without loading entire repositories. |
| Xray configuration | `/opt/security-assets/templates/xray` | Xray/XPOC configuration and rules. |
| Amass configuration | `/opt/security-assets/templates/amass` | Example Amass data-source configuration. |
| Gau configuration | `/opt/security-assets/templates/gau/.gau.toml` | Default configuration copied by the Gau wrapper. |
| Cent templates | `/opt/security-assets/templates/cent-nuclei-templates` | Community template collection managed by Cent. |
| Hermes Chromium | `/opt/hermes/.playwright` | Headless Chromium used by Hermes browser automation. |
| Oh My Zsh | `/opt/oh-my-zsh` | Shared, root-owned Oh My Zsh framework used by interactive root and Hermes shells. |
| Portable Zsh configuration | `/etc/zsh/portable.zshrc` | System-wide prompt, completion, history, aliases, key bindings, autosuggestions, and syntax-highlighting configuration. |

Do not edit immutable assets in `/opt`. Copy engagement-specific selections into `/workspace/config` or `/workspace/targets`.
"""


TROUBLESHOOTING = """# Troubleshooting

1. Confirm the command: `command -v COMMAND`.
2. Read the exact installed-version reference under `references/cli-help/`.
3. Verify the image: `check-tools` and `check-knowledge`.
4. Check Python environments with `/opt/toolchains/python/bin/pip check` and `/opt/toolchains/python-apps/sploitscan/bin/pip check`.
5. Put writable configuration and output under `/workspace`; `/opt/hermes`, `/opt/security-tools`, `/opt/security-assets`, and `/opt/toolchains` are immutable.
6. Raw-socket tools need the image capabilities and the configured privileged runtime. Privilege does not create authorization.
7. If a guide disagrees with runtime help, use the runtime help and resolved version, then update the guide.
"""


def guide(name: str, command: str) -> str:
    purpose = PURPOSES[name]
    source = SOURCES[name]
    category = category_for(name)
    example = EXAMPLES.get(name, f"{command} --help")
    specialized = ""
    if name == "cyberstrike":
        specialized = """
## Hermes delegation contract

Before invoking CyberStrike, load [`../cyberstrike/INDEX.md`](../cyberstrike/INDEX.md) and follow its non-interactive, deny-first automation protocol. The website documentation currently trails the installed CLI; do not use `cyberstrike config`, `--permission`, or `--output`.
"""
    return f"""---
tool: {name}
command: {command}
category: {category}
source: {source}
retrieved: {RETRIEVED}
---

# {name}

## Purpose

{purpose}

## Appropriate use

Use this command only for an explicitly authorized target and after reading [the safety rules](../SAFETY.md). Confirm the executable and installed-version syntax before testing.

## Prerequisites

- Set `ENGAGEMENT`, `TARGET`, `TARGET_DOMAIN`, or `TARGET_URL` as appropriate.
- Create `OUTPUT_DIR=/workspace/reports/$ENGAGEMENT/raw/{slug(name)}`.
- Configure any required provider credential only in runtime environment variables.

## Basic command

```bash
command -v {command}
{command} --help
```

## Intermediate example

```bash
mkdir -p "$OUTPUT_DIR"
{example}
```

## Advanced safe workflow

Load the matching category workflow from `../workflows/`, review the exact help snapshot, select only non-destructive options, set conservative concurrency/rate limits, and preserve raw output before normalization. Do not guess flags when the installed help differs from an upstream example.

```bash
timeout 60 {command} --help 2>&1 | tee "$OUTPUT_DIR/{slug(name)}-help.txt"
```

{specialized}
## Output and interpretation

{OUTPUTS[category]}

Preserve the exact command, timestamp, resolved version, target scope, raw output, and manual verification notes. A match is not automatically a vulnerability.

## Common problems

- `command not found`: run `check-tools` and inspect `/opt/security-manifest/tool-manifest.tsv`.
- Permission errors: write under `/workspace`, not immutable `/opt` directories.
- Empty or inconsistent results: verify scope, connectivity, required credentials, input format, and the installed-version flags.
- Rate limiting or instability: stop, reduce concurrency, and coordinate with the application owner.

## Verification

```bash
command -v {command}
check-tools
```

## Exact installed help

Load [`../cli-help/{slug(name)}.md`](../cli-help/{slug(name)}.md). It is generated during the Docker build from the installed executable.

## Authoritative source

- [{source}]({source})
- Source checked: {RETRIEVED}. Runtime help and `/opt/security-manifest/resolved-versions.txt` take precedence for the built image.
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace generated guides")
    args = parser.parse_args()

    tools_dir = SKILL_ROOT / "references/tools"
    workflows_dir = SKILL_ROOT / "references/workflows"
    cli_help_dir = SKILL_ROOT / "references/cli-help"
    for directory in (tools_dir, workflows_dir, cli_help_dir):
        directory.mkdir(parents=True, exist_ok=True)

    primary = [(name, command) for name, command in rows("command") if not name.startswith("legacy-")]
    missing_purpose = [name for name, _ in primary if name not in PURPOSES]
    missing_source = [name for name, _ in primary if name not in SOURCES]
    if missing_purpose or missing_source:
        raise SystemExit(f"missing purpose={missing_purpose}; missing source={missing_source}")

    for name, command in primary:
        path = tools_dir / f"{slug(name)}.md"
        if args.force or not path.exists():
            path.write_text(guide(name, command), encoding="utf-8")

    index_lines = [
        "# Offensive Workstation Tool Index",
        "",
        "Use this index when selecting a tool. Load one guide and the matching workflow; do not load the entire library.",
        "",
        "## Primary commands",
        "",
        "| Tool | Command | Category | Input | Output | Purpose | Guide |",
        "|---|---|---|---|---|---|---|",
    ]
    for name, command in primary:
        purpose = PURPOSES[name].replace("|", "\\|")
        category = category_for(name)
        input_type, output_type = IO_TYPES[category]
        index_lines.append(
            f"| {name} | `{command}` | {category} | {input_type} | {output_type} | {purpose} | [guide](tools/{slug(name)}.md) |"
        )
    index_lines += ["", "## Compatibility aliases", "", "| Alias | Canonical guide |", "|---|---|"]
    for alias, canonical in sorted(ALIASES.items(), key=lambda item: item[0].lower()):
        index_lines.append(f"| `{alias}` | [{canonical}](tools/{slug(canonical)}.md) |")
    index_lines += ["", "## Source-only paths", "", "| Name | Path |", "|---|---|"]
    for name, path in rows("path"):
        index_lines.append(f"| {name} | `{path}` |")
    index_lines += ["", "## Installed assets", "", "| Asset | Path | Usage |", "|---|---|---|"]
    for name, path in rows("asset"):
        if name == "hermes-pentesting-skill":
            continue
        index_lines.append(f"| {name} | `{path}` | [asset guidance](ASSETS.md) |")
    index_lines += [
        "",
        "## Knowledge package",
        "",
        "The baked Hermes skill is `/opt/hermes/skills/cybersecurity/offensive-workstation/SKILL.md`.",
    ]
    index_lines += ["", "## Capability checks", "", "| Check | Requirement |", "|---|---|"]
    for name, check in rows("capability"):
        index_lines.append(f"| {name} | `{check}` |")
    (SKILL_ROOT / "references/TOOL-INDEX.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")

    for filename, content in WORKFLOWS.items():
        (workflows_dir / filename).write_text(content.strip() + "\n", encoding="utf-8")
    (SKILL_ROOT / "references/SAFETY.md").write_text(SAFETY, encoding="utf-8")
    (SKILL_ROOT / "references/ASSETS.md").write_text(ASSETS, encoding="utf-8")
    (SKILL_ROOT / "references/TROUBLESHOOTING.md").write_text(TROUBLESHOOTING, encoding="utf-8")

    skill = """---
name: offensive-workstation-pentesting
description: Safely select, explain, and use the offensive workstation's installed security tools for authorized testing. Use whenever the user mentions CyberStrike, cyberstrike commands or flags, HackBrowser, CyberStrike agents, models, providers, authentication, configuration, permissions, sessions, skills, MCP, Bolt, or asks Hermes to explain or run CyberStrike.
metadata:
  hermes:
    tags: [security, pentesting, reconnaissance, web, authorized-testing]
    category: cybersecurity
---

# Offensive Workstation Pentesting

## When to use

Load this skill when the user asks Hermes to inventory, select, explain, combine, or operate the security tools installed in this image for an authorized assessment.

## Mandatory safety procedure

Before active testing, load `references/SAFETY.md`, establish written scope, and confirm that the user owns the target or has explicit authorization. Container privilege is a technical capability, not permission. Default to passive and non-destructive checks.

## Workspace contract

Set `ENGAGEMENT` and keep targets, raw results, evidence, and reports under `/workspace`. Never write target data into immutable `/opt` paths. Never place credentials in commands or reports.

```bash
export ENGAGEMENT=owned-application-review
export OUTPUT_DIR="/workspace/reports/$ENGAGEMENT"
mkdir -p "$OUTPUT_DIR"/{raw,normalized,evidence,final}
```

## Routing

1. For every CyberStrike-related request, first load `references/cyberstrike/INDEX.md` and its one matching topic page. For command or configuration questions, answer from the local RAG and installed help without invoking `cyberstrike run` or requiring a CyberStrike model-provider credential.
2. Load `references/TOOL-INDEX.md` if another required command is not already known.
3. Load exactly one relevant `references/tools/<tool>.md` guide.
4. Load the matching workflow only when chaining tools:
   - Recon and assets: `references/workflows/reconnaissance.md`, `references/workflows/dns-subdomains.md`, `references/workflows/enrichment.md`
   - Network: `references/workflows/network-mapping.md`
   - HTTP/routes: `references/workflows/http-discovery.md`, `references/workflows/content-fuzzing.md`
   - URLs/JavaScript: `references/workflows/url-javascript.md`
   - Templates/CMS: `references/workflows/template-scanning.md`, `references/workflows/cms-testing.md`
   - XSS/injection: `references/workflows/xss.md`, `references/workflows/injection.md`
   - Git/secrets: `references/workflows/git-secrets.md`
   - Browser/media: `references/workflows/browser-screenshots.md`
   - CyberStrike delegation: `references/cyberstrike/INDEX.md`, `references/workflows/cyberstrike-orchestration.md`
   - Evidence: `references/workflows/reporting-pipelines.md`
   - Converted PDF guide index: `references/my-guides/converted-source-index.md`
   - Web pentest methodology: `references/my-guides/web-pentest-guide.md`
   - Bug bounty methodology: `references/my-guides/bug-bounty-methodology.md`
   - Recon and fuzzing: `references/my-guides/recon-and-fuzzing.md`
   - API security testing: `references/my-guides/api-security-testing.md`
   - Authentication and access control: `references/my-guides/auth-access-control-testing.md`
   - JWT security testing: `references/my-guides/jwt-security-testing.md`
   - SQL injection testing: `references/my-guides/sql-injection-cheatsheet.md`
   - XSS testing: `references/my-guides/xss-cheatsheet.md`
   - LDAP injection testing: `references/my-guides/ldap-injection-testing.md`
   - File upload testing: `references/my-guides/file-upload-testing.md`
   - Deserialization testing: `references/my-guides/deserialization-testing.md`
   - WordPress and CMS testing: `references/my-guides/wordpress-cms-testing.md`
   - Mobile application testing: `references/my-guides/mobile-application-testing.md`
   - AWS cloud review: `references/my-guides/aws-cloud-security-review.md`
   - Network and service testing: `references/my-guides/network-service-testing.md`
   - SMTP testing: `references/my-guides/smtp-testing.md`
   - DoS resilience planning: `references/my-guides/dos-resilience-testing.md`
   - Payload library usage: `references/my-guides/payload-library.md`
   - Active Directory lab review: `references/my-guides/active-directory-lab-review.md`
   - Tunneling and port forwarding: `references/my-guides/tunneling-port-forwarding.md`
   - LLM application security: `references/my-guides/llm-application-security-testing.md`
   - Secure coding review: `references/my-guides/secure-coding-review.md`
   - Lab environment building: `references/my-guides/lab-environment-building.md`
   - Linux and Windows command reference: `references/my-guides/linux-windows-command-reference.md`
   - Certification study map: `references/my-guides/certification-study-map.md`
   - Tool selection: `references/my-guides/tool-selection-reference.md`
5. Consult `references/ASSETS.md` for wordlists/templates and `references/TROUBLESHOOTING.md` for failures.

## Execution rules

- Read the installed help snapshot before advanced use; tools track current releases and flags can change.
- Show the user the proposed active-scan scope and rate before high-volume execution.
- Use harmless markers and test accounts. Exclude destructive, persistence, credential-attack, denial-of-service, and third-party testing.
- Preserve raw output and report only manually verified findings with redacted evidence.

## Verification

```bash
check-tools
check-knowledge
COLUMNS=240 hermes skills list | grep offensive-workstation-pentesting
```
"""
    (SKILL_ROOT / "SKILL.md").write_text(skill, encoding="utf-8")
    help_lines = ["# tool<TAB>command<TAB>safe help arguments"]
    for name, command in primary:
        help_lines.append(f"{name}\t{command}\t{HELP_ARGS.get(name, '--help')}")
    (SKILL_ROOT / "help-commands.tsv").write_text("\n".join(help_lines) + "\n", encoding="utf-8")
    print(f"Generated {len(primary)} tool guides in {SKILL_ROOT}")


if __name__ == "__main__":
    main()
