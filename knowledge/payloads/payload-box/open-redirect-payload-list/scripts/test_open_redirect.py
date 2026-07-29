#!/usr/bin/env python3
"""
Open Redirect Vulnerability Testing Script
Author: Payload Box
Description: Automated testing tool for detecting open redirect vulnerabilities
"""

import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from urllib.parse import urljoin, urlparse

import requests


class Colors:
    """ANSI color codes for terminal output"""

    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"


class OpenRedirectTester:
    def __init__(
        self,
        base_url,
        payloads_file,
        parameters=None,
        threads=10,
        timeout=5,
        verbose=False,
    ):
        self.base_url = base_url
        self.payloads_file = payloads_file
        self.parameters = parameters or [
            "url",
            "redirect",
            "next",
            "return",
            "returnTo",
            "redir",
            "redirect_uri",
        ]
        self.threads = threads
        self.timeout = timeout
        self.verbose = verbose
        self.vulnerabilities = []
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }
        )

    def load_payloads(self):
        """Load payloads from file"""
        try:
            with open(self.payloads_file, "r", encoding="utf-8") as f:
                payloads = [
                    line.strip()
                    for line in f
                    if line.strip() and not line.startswith("#")
                ]
            print(f"{Colors.OKGREEN}[+] Loaded {len(payloads)} payloads{Colors.ENDC}")
            return payloads
        except FileNotFoundError:
            print(
                f"{Colors.FAIL}[!] Payloads file not found: {self.payloads_file}{Colors.ENDC}"
            )
            sys.exit(1)
        except Exception as e:
            print(f"{Colors.FAIL}[!] Error loading payloads: {e}{Colors.ENDC}")
            sys.exit(1)

    def test_payload(self, param, payload):
        """Test a single payload against a parameter"""
        try:
            # Build test URL
            separator = "&" if "?" in self.base_url else "?"
            test_url = f"{self.base_url}{separator}{param}={payload}"

            if self.verbose:
                print(f"{Colors.OKCYAN}[*] Testing: {test_url}{Colors.ENDC}")

            # Send request without following redirects
            response = self.session.get(
                test_url, allow_redirects=False, timeout=self.timeout, verify=False
            )

            # Check for redirect response
            if response.status_code in [301, 302, 303, 307, 308]:
                location = response.headers.get("Location", "")

                # Check if payload is in Location header
                if self.is_vulnerable(payload, location):
                    vuln_info = {
                        "url": test_url,
                        "parameter": param,
                        "payload": payload,
                        "status_code": response.status_code,
                        "location": location,
                        "timestamp": datetime.now().isoformat(),
                    }
                    self.vulnerabilities.append(vuln_info)
                    print(
                        f"{Colors.OKGREEN}[VULNERABLE] {Colors.BOLD}{test_url}{Colors.ENDC}"
                    )
                    print(f"{Colors.WARNING}[REDIRECT TO] {location}{Colors.ENDC}\n")
                    return vuln_info

        except requests.exceptions.Timeout:
            if self.verbose:
                print(f"{Colors.WARNING}[!] Timeout: {test_url}{Colors.ENDC}")
        except requests.exceptions.RequestException as e:
            if self.verbose:
                print(f"{Colors.FAIL}[!] Error: {test_url} - {e}{Colors.ENDC}")
        except Exception as e:
            if self.verbose:
                print(f"{Colors.FAIL}[!] Unexpected error: {e}{Colors.ENDC}")

        return None

    def is_vulnerable(self, payload, location):
        """Check if the redirect location indicates a vulnerability"""
        # Evil domain indicators (used in payloads)
        indicators = ["evil.com", "google.com", "127.0.0.1", "localhost"]

        # Check if any indicator is in the location
        for indicator in indicators:
            if indicator in location.lower():
                return True

        # Check for protocol-relative URLs
        if payload.startswith("//") and location.startswith("//"):
            return True

        # Check for JavaScript URIs
        if payload.startswith("javascript:") and "javascript:" in location.lower():
            return True

        # Check for data URIs
        if payload.startswith("data:") and "data:" in location.lower():
            return True

        # Check if payload is reflected in location
        try:
            # URL decode and compare
            from urllib.parse import unquote

            if unquote(payload) in unquote(location):
                return True
        except:
            pass

        return False

    def run(self):
        """Run the vulnerability test"""
        print(f"{Colors.HEADER}{Colors.BOLD}")
        print("=" * 60)
        print("    Open Redirect Vulnerability Scanner")
        print("=" * 60)
        print(f"{Colors.ENDC}")
        print(f"{Colors.OKBLUE}[*] Target URL: {self.base_url}{Colors.ENDC}")
        print(
            f"{Colors.OKBLUE}[*] Parameters: {', '.join(self.parameters)}{Colors.ENDC}"
        )
        print(f"{Colors.OKBLUE}[*] Threads: {self.threads}{Colors.ENDC}")
        print(f"{Colors.OKBLUE}[*] Timeout: {self.timeout}s{Colors.ENDC}\n")

        # Load payloads
        payloads = self.load_payloads()

        # Create test cases
        test_cases = []
        for param in self.parameters:
            for payload in payloads:
                test_cases.append((param, payload))

        print(f"{Colors.OKGREEN}[+] Total test cases: {len(test_cases)}{Colors.ENDC}")
        print(f"{Colors.OKGREEN}[+] Starting scan...{Colors.ENDC}\n")

        # Run tests with threading
        with ThreadPoolExecutor(max_workers=self.threads) as executor:
            futures = {
                executor.submit(self.test_payload, param, payload): (param, payload)
                for param, payload in test_cases
            }

            completed = 0
            for future in as_completed(futures):
                completed += 1
                if not self.verbose and completed % 50 == 0:
                    print(
                        f"{Colors.OKCYAN}[*] Progress: {completed}/{len(test_cases)}{Colors.ENDC}"
                    )
                future.result()

        # Print results
        self.print_results()

    def print_results(self):
        """Print scan results"""
        print(f"\n{Colors.HEADER}{Colors.BOLD}")
        print("=" * 60)
        print("    Scan Results")
        print("=" * 60)
        print(f"{Colors.ENDC}")

        if self.vulnerabilities:
            print(
                f"{Colors.FAIL}[!] Found {len(self.vulnerabilities)} potential vulnerabilities:{Colors.ENDC}\n"
            )
            for i, vuln in enumerate(self.vulnerabilities, 1):
                print(f"{Colors.BOLD}Vulnerability #{i}:{Colors.ENDC}")
                print(f"  URL: {vuln['url']}")
                print(f"  Parameter: {vuln['parameter']}")
                print(f"  Payload: {vuln['payload']}")
                print(f"  Status Code: {vuln['status_code']}")
                print(f"  Redirect To: {vuln['location']}")
                print(f"  Timestamp: {vuln['timestamp']}\n")
        else:
            print(f"{Colors.OKGREEN}[+] No vulnerabilities detected{Colors.ENDC}")

    def save_results(self, output_file):
        """Save results to JSON file"""
        if self.vulnerabilities:
            try:
                with open(output_file, "w") as f:
                    json.dump(
                        {
                            "scan_date": datetime.now().isoformat(),
                            "target": self.base_url,
                            "vulnerabilities": self.vulnerabilities,
                        },
                        f,
                        indent=2,
                    )
                print(
                    f"{Colors.OKGREEN}[+] Results saved to {output_file}{Colors.ENDC}"
                )
            except Exception as e:
                print(f"{Colors.FAIL}[!] Error saving results: {e}{Colors.ENDC}")


def main():
    parser = argparse.ArgumentParser(
        description="Open Redirect Vulnerability Testing Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python test_open_redirect.py -u https://example.com/redirect
  python test_open_redirect.py -u https://example.com/redirect -p url,next,return
  python test_open_redirect.py -u https://example.com/redirect -t 20 -o results.json
  python test_open_redirect.py -u https://example.com/redirect -v --timeout 10
        """,
    )

    parser.add_argument("-u", "--url", required=True, help="Target URL to test")
    parser.add_argument(
        "-f",
        "--file",
        default="../payloads.txt",
        help="Payloads file (default: ../payloads.txt)",
    )
    parser.add_argument(
        "-p",
        "--params",
        help="Comma-separated list of parameters to test (default: url,redirect,next,return,returnTo,redir,redirect_uri)",
    )
    parser.add_argument(
        "-t", "--threads", type=int, default=10, help="Number of threads (default: 10)"
    )
    parser.add_argument(
        "--timeout", type=int, default=5, help="Request timeout in seconds (default: 5)"
    )
    parser.add_argument("-o", "--output", help="Output file for results (JSON format)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    args = parser.parse_args()

    # Parse parameters
    params = None
    if args.params:
        params = [p.strip() for p in args.params.split(",")]

    # Disable SSL warnings
    import urllib3

    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # Create tester instance
    tester = OpenRedirectTester(
        base_url=args.url,
        payloads_file=args.file,
        parameters=params,
        threads=args.threads,
        timeout=args.timeout,
        verbose=args.verbose,
    )

    # Run the test
    try:
        tester.run()

        # Save results if output file specified
        if args.output:
            tester.save_results(args.output)

    except KeyboardInterrupt:
        print(f"\n{Colors.WARNING}[!] Scan interrupted by user{Colors.ENDC}")
        sys.exit(0)
    except Exception as e:
        print(f"{Colors.FAIL}[!] Fatal error: {e}{Colors.ENDC}")
        sys.exit(1)


if __name__ == "__main__":
    main()
