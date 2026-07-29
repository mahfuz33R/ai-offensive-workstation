#!/bin/bash

#############################################
# Quick Open Redirect Testing Script
# Author: Payload Box
# Description: Fast bash script for testing open redirect vulnerabilities
#############################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
PAYLOADS_FILE="../payloads.txt"
TIMEOUT=5
VERBOSE=0
OUTPUT_FILE=""

# Banner
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "=========================================="
    echo "  Quick Open Redirect Testing Script"
    echo "=========================================="
    echo -e "${NC}"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 -u <URL> [OPTIONS]

Options:
    -u, --url <URL>          Target URL (required)
    -p, --param <PARAM>      Parameter name (default: url)
    -f, --file <FILE>        Payloads file (default: ../payloads.txt)
    -t, --timeout <SEC>      Request timeout (default: 5)
    -o, --output <FILE>      Save results to file
    -v, --verbose            Verbose output
    -h, --help               Show this help message

Examples:
    $0 -u "https://example.com/redirect"
    $0 -u "https://example.com/redirect" -p next
    $0 -u "https://example.com/redirect" -p url -o results.txt
    $0 -u "https://example.com/redirect" -v -t 10

EOF
}

# Check dependencies
check_dependencies() {
    local missing=0

    if ! command -v curl &> /dev/null; then
        echo -e "${RED}[!] curl is not installed${NC}"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo -e "${RED}[!] Please install missing dependencies${NC}"
        exit 1
    fi
}

# Test a single payload
test_payload() {
    local url="$1"
    local param="$2"
    local payload="$3"

    # Construct test URL
    if [[ $url == *"?"* ]]; then
        test_url="${url}&${param}=${payload}"
    else
        test_url="${url}?${param}=${payload}"
    fi

    # Verbose output
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${CYAN}[*] Testing: ${test_url}${NC}"
    fi

    # Send request and capture response
    response=$(curl -s -L -o /dev/null -w "%{http_code}|%{redirect_url}" \
               --max-time "$TIMEOUT" \
               --max-redirs 0 \
               -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
               "$test_url" 2>/dev/null)

    # Parse response
    http_code=$(echo "$response" | cut -d'|' -f1)
    redirect_url=$(echo "$response" | cut -d'|' -f2)

    # Check if it's a redirect
    if [[ "$http_code" =~ ^30[12378]$ ]]; then
        # Check if payload is reflected in redirect
        if [[ "$redirect_url" == *"evil.com"* ]] || \
           [[ "$redirect_url" == *"google.com"* ]] || \
           [[ "$redirect_url" == *"127.0.0.1"* ]] || \
           [[ "$redirect_url" == *"localhost"* ]] || \
           [[ "$redirect_url" == *"javascript:"* ]] || \
           [[ "$redirect_url" == *"data:"* ]]; then

            echo -e "${GREEN}${BOLD}[VULNERABLE]${NC} ${test_url}"
            echo -e "${YELLOW}[REDIRECT TO]${NC} ${redirect_url}"
            echo ""

            # Save to output file if specified
            if [ -n "$OUTPUT_FILE" ]; then
                echo "[VULNERABLE] $test_url" >> "$OUTPUT_FILE"
                echo "[REDIRECT TO] $redirect_url" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
            fi

            return 0
        fi
    fi

    return 1
}

# Main testing function
run_test() {
    local url="$1"
    local param="$2"

    # Check if payloads file exists
    if [ ! -f "$PAYLOADS_FILE" ]; then
        echo -e "${RED}[!] Payloads file not found: $PAYLOADS_FILE${NC}"
        exit 1
    fi

    # Count payloads
    total_payloads=$(grep -v '^#' "$PAYLOADS_FILE" | grep -v '^$' | wc -l)

    echo -e "${BLUE}[*] Target URL: ${url}${NC}"
    echo -e "${BLUE}[*] Parameter: ${param}${NC}"
    echo -e "${BLUE}[*] Payloads: ${total_payloads}${NC}"
    echo -e "${BLUE}[*] Timeout: ${TIMEOUT}s${NC}"
    echo ""
    echo -e "${GREEN}[+] Starting test...${NC}"
    echo ""

    # Initialize counters
    tested=0
    vulnerable=0

    # Read and test each payload
    while IFS= read -r payload; do
        # Skip comments and empty lines
        [[ "$payload" =~ ^#.*$ ]] && continue
        [[ -z "$payload" ]] && continue

        ((tested++))

        # Test the payload
        if test_payload "$url" "$param" "$payload"; then
            ((vulnerable++))
        fi

        # Show progress every 50 payloads
        if [ $VERBOSE -eq 0 ] && [ $((tested % 50)) -eq 0 ]; then
            echo -e "${CYAN}[*] Progress: ${tested}/${total_payloads}${NC}"
        fi

    done < "$PAYLOADS_FILE"

    # Print results
    echo ""
    echo -e "${BLUE}${BOLD}=========================================="
    echo "  Scan Results"
    echo "==========================================${NC}"
    echo ""
    echo -e "${BLUE}[*] Total payloads tested: ${tested}${NC}"

    if [ $vulnerable -gt 0 ]; then
        echo -e "${RED}${BOLD}[!] Potential vulnerabilities found: ${vulnerable}${NC}"

        if [ -n "$OUTPUT_FILE" ]; then
            echo -e "${GREEN}[+] Results saved to: ${OUTPUT_FILE}${NC}"
        fi
    else
        echo -e "${GREEN}[+] No vulnerabilities detected${NC}"
    fi
    echo ""
}

# Parse command line arguments
parse_args() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--url)
                URL="$2"
                shift 2
                ;;
            -p|--param)
                PARAM="$2"
                shift 2
                ;;
            -f|--file)
                PAYLOADS_FILE="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Unknown option: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done

    # Check required arguments
    if [ -z "$URL" ]; then
        echo -e "${RED}[!] URL is required${NC}"
        usage
        exit 1
    fi

    # Set default parameter if not specified
    if [ -z "$PARAM" ]; then
        PARAM="url"
    fi
}

# Main execution
main() {
    print_banner
    check_dependencies
    parse_args "$@"

    # Clear output file if it exists
    if [ -n "$OUTPUT_FILE" ]; then
        > "$OUTPUT_FILE"
        echo "Open Redirect Scan Results" >> "$OUTPUT_FILE"
        echo "Date: $(date)" >> "$OUTPUT_FILE"
        echo "Target: $URL" >> "$OUTPUT_FILE"
        echo "Parameter: $PARAM" >> "$OUTPUT_FILE"
        echo "======================================" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    # Run the test
    run_test "$URL" "$PARAM"
}

# Trap Ctrl+C
trap ctrl_c INT

function ctrl_c() {
    echo ""
    echo -e "${YELLOW}[!] Scan interrupted by user${NC}"
    exit 0
}

# Execute main function
main "$@"
