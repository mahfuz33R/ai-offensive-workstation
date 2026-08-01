from __future__ import annotations

import re
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def service_block(compose: str, name: str) -> str:
    pattern = rf"(?ms)^  {re.escape(name)}:\n(.*?)(?=^  [a-zA-Z0-9_-]+:\n|^(?:networks|volumes|secrets):)"
    match = re.search(pattern, compose)
    if not match:
        raise AssertionError(f"service not found: {name}")
    return match.group(0)


class KaliBaseTests(unittest.TestCase):
    def test_official_kali_is_the_direct_base(self) -> None:
        dockerfile = read("Dockerfile")
        self.assertIn("ARG KALI_IMAGE=kalilinux/kali-last-release", dockerfile)
        self.assertIn(
            "FROM ${KALI_IMAGE}:${KALI_TAG}${KALI_DIGEST}", dockerfile
        )
        self.assertIn(
            'KALI_IMAGE="${KALI_IMAGE}" bash /tmp/install/install-kali-base.sh',
            dockerfile,
        )
        self.assertNotIn("FROM nousresearch/hermes-agent", dockerfile.lower())
        kali_installer = read("scripts/install-kali-base.sh")
        self.assertIn("kali-linux-headless", kali_installer)
        self.assertIn("apt-get -y full-upgrade", kali_installer)
        self.assertIn("apt-cache show nmap", kali_installer)
        self.assertIn("expected_suite=kali-last-snapshot", kali_installer)

    def test_hermes_is_directly_installed_from_latest_stable_release(self) -> None:
        installer = read("scripts/install-hermes.sh")
        self.assertIn("releases/latest", installer)
        self.assertIn("refs/tags/${resolved_ref}", installer)
        self.assertIn(
            '"${resolved_ref}:scripts/install.sh"',
            installer,
        )
        self.assertIn('git hash-object "$installer_file"', installer)
        self.assertIn("/usr/local/lib/hermes-agent", installer)
        self.assertIn("/usr/local/bin/hermes", installer)
        self.assertIn("--skip-setup", installer)
        self.assertIn("--skip-browser", installer)

    def test_cyberstrike_uses_the_official_stable_dist_tag(self) -> None:
        installer = read("scripts/install-cyberstrike.sh")
        self.assertIn('@cyberstrike-io/cyberstrike"', installer)
        self.assertIn('CYBERSTRIKE_VERSION:-latest', installer)
        self.assertIn('"${CYBERSTRIKE_PACKAGE}@${version_selector}"', installer)
        self.assertIn("npm view", installer)
        self.assertIn("CYBERSTRIKE_PERSISTENT_HOME", installer)
        self.assertIn('export XDG_DATA_HOME="$CYBERSTRIKE_PERSISTENT_HOME/data"', installer)

    def test_current_browser_stack_requires_a_supported_node_line(self) -> None:
        node_installer = read("scripts/install-node.sh")
        self.assertIn("NODE_VERSION:-latest", node_installer)
        self.assertIn("NPM_VERSION:-latest", node_installer)
        self.assertIn("nodejs.org/dist/index.json", node_installer)
        self.assertIn("sha256sum --check", node_installer)
        self.assertIn("major >= 24", node_installer)
        self.assertIn("PLAYWRIGHT_VERSION=1.62.0", read("Dockerfile"))


class IdentityAndShellTests(unittest.TestCase):
    def test_hermes_is_a_dedicated_container_admin(self) -> None:
        base = read("scripts/install-kali-base.sh")
        entrypoint = read("scripts/workstation-entrypoint.sh")
        self.assertIn("useradd", base)
        self.assertIn("hermes ALL=(ALL:ALL) NOPASSWD: ALL", base)
        self.assertIn("gosu", entrypoint)
        self.assertIn("exec gosu", entrypoint)
        self.assertIn("if [[ \"${1:-}\" == root ]]", entrypoint)
        self.assertIn("ln -sfn /opt/data /home/hermes/.hermes", read("Dockerfile"))

    def test_zsh_is_standard_for_root_and_hermes(self) -> None:
        installer = read("scripts/install-zsh.sh")
        entrypoint = read("scripts/workstation-entrypoint.sh")
        for path in (
            "/etc/zsh/portable.zshrc",
            "/etc/skel/.zshrc",
            "/root/.zshrc",
            "/home/hermes/.zshrc",
        ):
            self.assertIn(path, installer)
        self.assertIn("usermod --shell /usr/bin/zsh root", installer)
        self.assertIn("usermod --shell /usr/bin/zsh hermes", installer)
        self.assertIn("install_user_zshrc /root/.zshrc", entrypoint)
        self.assertIn("install_user_zshrc /home/hermes/.zshrc", entrypoint)
        self.assertIn("source /etc/zsh/portable.zshrc", entrypoint)
        self.assertIn("AI_OFFENSIVE_ZSH_LOADED", read(".zshrc"))
        self.assertIn("zstyle ':omz:update' mode disabled", read(".zshrc"))

    def test_zshrc_has_clean_unix_text_and_highlighting_is_last(self) -> None:
        raw = (ROOT / ".zshrc").read_bytes()
        self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
        self.assertNotIn(b"\r", raw)
        unexpected_controls = {
            byte for byte in raw if byte < 32 and byte not in (9, 10)
        }
        self.assertEqual(set(), unexpected_controls)

        zshrc = raw.decode("ascii")
        final_source = 'source "$ZSH_SYNTAX_HIGHLIGHTING_FILE"'
        self.assertIn(final_source, zshrc)
        self.assertEqual(
            "fi",
            next(
                line.strip()
                for line in reversed(zshrc.splitlines())
                if line.strip() and not line.lstrip().startswith("#")
            ),
        )

    def test_all_tool_locations_are_global(self) -> None:
        dockerfile = read("Dockerfile")
        zshrc = read(".zshrc")
        for path in (
            "/usr/local/bin",
            "/opt/toolchains/node/bin",
            "/opt/toolchains/go/bin",
            "/opt/toolchains/python/bin",
            "/opt/toolchains/cargo/bin",
            "/opt/browser-tools/playwright/node_modules/.bin",
            "/workspace/bin",
            "/workspace/scripts",
        ):
            self.assertIn(path, dockerfile + zshrc)
        self.assertIn(
            "AGENT_BROWSER_EXECUTABLE_PATH=/opt/browser-tools/chromium",
            dockerfile,
        )
        browser_installer = read("scripts/install-browser-automation.sh")
        hermes_installer = read("scripts/install-hermes.sh")
        self.assertIn("AGENT_BROWSER_VERSION:-latest", browser_installer)
        self.assertIn("AgentBrowserOK", browser_installer)
        self.assertIn("verify_agent_browser", browser_installer)
        self.assertIn("attempt ${attempt}/3", browser_installer)
        self.assertIn("timeout --kill-after=10 90", browser_installer)
        self.assertIn("timeout --kill-after=10 120 node", browser_installer)
        self.assertIn(
            "playwright install chromium firefox",
            browser_installer,
        )
        self.assertIn("npm run build -w web", hermes_installer)
        self.assertIn('"firefox", firefox', browser_installer)
        self.assertIn("command -v chromium firefox-esr", browser_installer)

    def test_stale_gateway_cleanup_is_scoped_to_compose_foreground_run(self) -> None:
        entrypoint = read("scripts/workstation-entrypoint.sh")
        match = re.search(
            r"clear_stale_foreground_gateway_state\(\) \{.*?\n\}",
            entrypoint,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        cleanup = match.group(0) if match else ""
        self.assertNotIn("rm -rf", cleanup)
        self.assertIn('clear_stale_foreground_gateway_state "$@"', entrypoint)

        def invoke(home: Path, arguments: list[str]) -> None:
            script = "\n".join(
                (
                    "set -euo pipefail",
                    f"HERMES_HOME={shlex.quote(str(home))}",
                    cleanup,
                    "clear_stale_foreground_gateway_state " + shlex.join(arguments),
                )
            )
            subprocess.run(["bash", "-c", script], check=True, capture_output=True)

        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            markers = [home / "gateway.pid", home / "gateway.lock"]

            for marker in markers:
                marker.write_text("stale\n", encoding="utf-8")
            invoke(home, ["hermes", "gateway", "run"])
            self.assertTrue(all(not marker.exists() for marker in markers))

            targets = [home / "pid-target", home / "lock-target"]
            for marker, target in zip(markers, targets, strict=True):
                target.write_text("keep\n", encoding="utf-8")
                marker.symlink_to(target)
            invoke(home, ["hermes", "gateway", "run"])
            self.assertTrue(all(not marker.is_symlink() for marker in markers))
            self.assertTrue(all(target.read_text(encoding="utf-8") == "keep\n" for target in targets))

            unrelated_commands = (
                ["hermes", "gateway", "restart"],
                ["hermes", "dashboard"],
                ["hermes", "setup"],
                ["zsh"],
                [],
            )
            for arguments in unrelated_commands:
                with self.subTest(arguments=arguments):
                    for marker in markers:
                        marker.write_text("preserve\n", encoding="utf-8")
                    invoke(home, arguments)
                    self.assertTrue(all(marker.exists() for marker in markers))

            marker_directory = home / "gateway.lock"
            marker_directory.unlink()
            marker_directory.mkdir()
            nested = marker_directory / "nested"
            nested.write_text("keep\n", encoding="utf-8")
            invoke(home, ["hermes", "gateway", "run"])
            self.assertEqual("keep\n", nested.read_text(encoding="utf-8"))


class ComposeIsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.compose = read("docker-compose.yml")

    def test_no_host_namespace_or_docker_control_mounts(self) -> None:
        self.assertNotRegex(self.compose, r"(?m)^\s*privileged:\s*true\s*$")
        self.assertNotRegex(self.compose, r"(?m)^\s*network_mode:\s*host\s*$")
        self.assertNotIn("/var/run/docker.sock", self.compose)
        self.assertNotIn("pid: host", self.compose)
        self.assertNotIn("ipc: host", self.compose)
        self.assertNotIn("seccomp=unconfined", self.compose)
        self.assertNotIn("apparmor=unconfined", self.compose)

    def test_workstation_uses_bridge_nat_and_local_ports(self) -> None:
        self.assertIn("driver: bridge", self.compose)
        self.assertIn("internal: false", self.compose)
        self.assertIn('"127.0.0.1:8656:8656"', self.compose)
        self.assertIn(
            '"127.0.0.1:${HERMES_DASHBOARD_PORT:-9119}:9119"',
            self.compose,
        )
        runtime_anchor = self.compose.split("services:", 1)[0]
        self.assertIn('API_SERVER_ENABLED: "true"', runtime_anchor)
        self.assertIn("API_SERVER_HOST: 0.0.0.0", runtime_anchor)
        self.assertIn('API_SERVER_PORT: "8656"', runtime_anchor)

    def test_existing_host_volume_contract_is_preserved(self) -> None:
        self.assertIn(
            "${HERMES_DATA_DIR:-./workspace/container-opt/data}:/opt/data",
            self.compose,
        )
        self.assertIn(
            "${WORKSTATION_ROOT_DIR:-./workspace/container-root}:/root",
            self.compose,
        )
        self.assertIn("./workspace:/workspace", self.compose)

    def test_malware_profile_has_no_host_bind_or_network(self) -> None:
        block = service_block(self.compose, "malware-lab")
        self.assertIn("network_mode: none", block)
        self.assertIn("read_only: true", block)
        self.assertIn("no-new-privileges:true", block)
        self.assertIn("- ALL", block)
        self.assertIn('user: "10000:10000"', block)
        self.assertIn("working_dir: /analysis", block)
        self.assertIn('entrypoint: ["/usr/bin/tini", "--"]', block)
        self.assertIn("malware-analysis:/analysis", block)
        self.assertNotIn("./workspace", block)
        self.assertNotIn("WORKSTATION_ROOT_DIR", block)
        self.assertNotIn("HERMES_DATA_DIR", block)
        self.assertNotIn("env_file:", block)

    def test_normal_services_use_the_single_private_environment_file(self) -> None:
        runtime_anchor = self.compose.split("services:", 1)[0]
        self.assertIn("env_file:", runtime_anchor)
        self.assertIn("- path: .env", runtime_anchor)
        self.assertIn("required: true", runtime_anchor)

    def test_cyberstrike_api_is_internal_and_shared_with_hermes(self) -> None:
        block = service_block(self.compose, "cyberstrike-api")
        self.assertIn('network_mode: "service:workstation"', block)
        self.assertIn("networks: []", block)
        self.assertIn("--hostname 127.0.0.1 --port 4096", block)
        self.assertIn("/global/health", block)
        self.assertIn("openssl rand -hex 32", block)
        self.assertNotIn("ports:", block)
        runtime_anchor = self.compose.split("services:", 1)[0]
        self.assertIn(
            "CYBERSTRIKE_PERSISTENT_HOME: /opt/data/cyberstrike",
            runtime_anchor,
        )


class BuildContractTests(unittest.TestCase):
    def test_every_local_docker_copy_source_exists(self) -> None:
        logical_lines: list[str] = []
        pending = ""
        for raw_line in read("Dockerfile").splitlines():
            line = raw_line.strip()
            pending = f"{pending} {line}".strip()
            if pending.endswith("\\"):
                pending = pending[:-1].rstrip()
                continue
            logical_lines.append(pending)
            pending = ""

        missing: list[str] = []
        for line in logical_lines:
            if not line.startswith("COPY "):
                continue
            tokens = shlex.split(line)
            sources = [token for token in tokens[1:-1] if not token.startswith("--")]
            for source in sources:
                if not (ROOT / source.rstrip("/")).exists():
                    missing.append(source)
        self.assertEqual([], missing)

    def test_entrypoint_and_inventory_are_build_gates(self) -> None:
        dockerfile = read("Dockerfile")
        runtime_verifier = read("scripts/verify-runtime.sh")
        self.assertIn(
            'ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/workstation-entrypoint"]',
            dockerfile,
        )
        self.assertIn("/tmp/install/verify-installation.sh", dockerfile)
        self.assertIn("/tmp/install/verify-knowledge-base.py --require-help", dockerfile)
        self.assertIn("network inspect --format '{{.Driver}}'", runtime_verifier)
        self.assertIn('gateway_host_ip" == 127.0.0.1', runtime_verifier)

    def test_bundled_skill_has_image_and_runtime_locations(self) -> None:
        dockerfile = read("Dockerfile")
        entrypoint = read("scripts/workstation-entrypoint.sh")
        inventory = read("scripts/manifests/tool-inventory.tsv")
        image_path = (
            "/usr/local/share/hermes/skills/cybersecurity/offensive-workstation"
        )
        runtime_path = (
            "$HERMES_HOME/skills/cybersecurity/offensive-workstation"
        )
        self.assertIn(image_path, dockerfile)
        self.assertIn(image_path, inventory)
        self.assertIn(runtime_path, entrypoint)
        self.assertIn("flock 9", entrypoint)
        self.assertIn('cp -a "$HERMES_BUNDLED_SKILL_DIR/."', entrypoint)

    def test_cyberstrike_hybrid_rag_and_memory_are_persistent(self) -> None:
        dockerfile = read("Dockerfile")
        entrypoint = read("scripts/workstation-entrypoint.sh")
        inventory = read("scripts/manifests/tool-inventory.tsv")
        skill = read(
            "knowledge/skills/offensive-workstation-pentesting/SKILL.md"
        )
        user_source = read(
            "knowledge/skills/offensive-workstation-pentesting/"
            "references/cyberstrike/source-library/user/"
            "cyberstrike-agent-knowledge-base.md"
        )
        self.assertIn("install-cyberstrike-kb.sh", dockerfile)
        self.assertIn(
            "#!/opt/toolchains/python-apps/cyberstrike-kb/bin/python",
            read("scripts/cyberstrike-kb.py"),
        )
        self.assertIn("FASTEMBED_CACHE_PATH", dockerfile)
        self.assertIn(
            "/usr/local/share/hermes/knowledge/cyberstrike/"
            "cyberstrike-kb.sqlite3",
            dockerfile,
        )
        self.assertIn("cyberstrike-kb", dockerfile)
        self.assertIn("verify", dockerfile)
        self.assertIn("HERMES_BUNDLED_CYBERSTRIKE_KB", entrypoint)
        self.assertIn("CYBERSTRIKE_MEMORY_MARKER", entrypoint)
        self.assertIn("$HERMES_HOME/memories", entrypoint)
        self.assertIn("HERMES_MEMORY_LIMIT=2200", entrypoint)
        self.assertIn(
            "command\tcyberstrike-kb\tcyberstrike-kb", inventory
        )
        self.assertIn("asset\tcyberstrike-vector-kb\t", inventory)
        self.assertIn('cyberstrike-kb search "$USER_INTENT"', skill)
        self.assertIn("command\tworkstation-kb\tworkstation-kb", inventory)
        self.assertIn("asset\tworkstation-vector-kb\t", inventory)
        self.assertIn("HERMES_BUNDLED_WORKSTATION_KB", entrypoint)
        self.assertIn("WORKSTATION_MEMORY_MARKER", entrypoint)
        self.assertIn('workstation-kb search "$USER_INTENT"', skill)
        self.assertIn("user-supplied-unverified", user_source)

    def test_hermes_has_a_verified_cyberstrike_mcp_bridge(self) -> None:
        entrypoint = read("scripts/workstation-entrypoint.sh")
        adapter = read(
            "knowledge/skills/offensive-workstation-pentesting/"
            "scripts/cyberstrike_mcp.py"
        )
        verified_api = read(
            "knowledge/skills/offensive-workstation-pentesting/"
            "references/cyberstrike/VERIFIED-API.md"
        )
        runtime_verifier = read("scripts/verify-runtime.sh")
        self.assertIn("configure_cyberstrike_mcp", entrypoint)
        self.assertIn("hermes mcp add cyberstrike", entrypoint)
        self.assertIn("FastMCP", adapter)
        self.assertIn('DEFAULT_API_URL = "http://127.0.0.1:4096"', adapter)
        self.assertIn('"/global/health"', adapter)
        self.assertNotIn('"/api/health"', adapter)
        self.assertIn("confirm=true", verified_api)
        self.assertIn("hermes mcp test cyberstrike", runtime_verifier)
        self.assertIn("len(names) == 9", runtime_verifier)
        self.assertIn("check_and_delete_cyberstrike_session_sentinel", runtime_verifier)
        self.assertIn("wait_for_gateway_api", runtime_verifier)
        self.assertIn(
            "Hermes API rejects unauthenticated access",
            runtime_verifier,
        )

    def test_host_and_reuse_environment_files_follow_kali(self) -> None:
        combined = (
            read(".env.example")
            + read("scripts/configure-host.sh")
            + read("scripts/reuse.sh")
        )
        self.assertIn("KALI_IMAGE=kalilinux/kali-last-release", combined)
        self.assertIn("HERMES_VERSION=latest", combined)
        self.assertIn("CYBERSTRIKE_VERSION=latest", combined)
        self.assertIn("AGENT_BROWSER_VERSION=latest", combined)
        self.assertIn("PLAYWRIGHT_VERSION=1.62.0", combined)
        self.assertNotIn("HERMES_IMAGE=nousresearch/hermes-agent", combined)
        self.assertIn("HOST_UID=10000", read("scripts/configure-host.sh"))
        self.assertIn(
            'HERMES_ENV_FILE="$PERSISTENT_OPT_DATA_DIR/.env"',
            read("scripts/configure-host.sh"),
        )
        self.assertNotIn("secrets.env", read("docker-compose.yml"))
        configure_host = read("scripts/configure-host.sh")
        self.assertIn("API_SERVER_KEY", configure_host)
        self.assertIn("openssl rand -hex 32", configure_host)
        self.assertIn(
            "HERMES_DATA_DIR=./workspace/container-opt/data",
            configure_host,
        )
        self.assertIn(
            "WORKSTATION_ROOT_DIR=./workspace/container-root",
            configure_host,
        )
        for public_path in (
            ".env.example",
            "docker-compose.yml",
            "Dockerfile",
            "scripts/build-and-verify.sh",
            "scripts/configure-host.sh",
        ):
            public_text = read(public_path)
            self.assertNotIn("GITHUB_TOKEN", public_text)
            self.assertNotIn("github_token", public_text)

    def test_reuse_script_and_guide_use_the_consolidated_layout(self) -> None:
        reuse_script = read("scripts/reuse.sh")
        reuse_guide = read("docs/REUSE.md")
        self.assertIn("state_entries+=(.env)", reuse_script)
        self.assertIn("scripts/configure-host.sh", reuse_script)
        self.assertIn("The private root `.env`", reuse_guide)
        self.assertIn("workspace.before-reuse-*", reuse_guide)
        self.assertNotIn("secrets.env", reuse_script + reuse_guide)

    def test_large_security_asset_collections_are_build_verified(self) -> None:
        installer = read("scripts/install-assets.sh")
        for required in (
            "verify_asset_collections",
            "SecLists/Discovery/Web-Content",
            "nuclei-templates/http",
            "nuclei -version",
            "seclists_count >= 100",
            "nuclei_count >= 100",
            "payload_count >= 100",
        ):
            self.assertIn(required, installer)


if __name__ == "__main__":
    unittest.main()
