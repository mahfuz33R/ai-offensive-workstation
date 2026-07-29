#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

root = File.expand_path("..", __dir__)
compose = YAML.safe_load(
  File.read(File.join(root, "docker-compose.yml")),
  aliases: true
)
services = compose.fetch("services")

expected_binds = [
  "${HERMES_DATA_DIR:-./workspace/container-opt/data}:/opt/data",
  "${WORKSTATION_ROOT_DIR:-./workspace/container-root}:/root",
  "./workspace:/workspace"
]

%w[workstation setup].each do |name|
  service = services.fetch(name)
  raise "#{name}: missing bridge network" unless service.fetch("networks") == ["workstation-nat"]
end

%w[dashboard cyberstrike-api].each do |name|
  service = services.fetch(name)
  unless service["network_mode"] == "service:workstation" &&
         service.fetch("networks") == []
    raise "#{name}: must share the workstation loopback namespace"
  end
end

%w[workstation dashboard cyberstrike-api setup].each do |name|
  service = services.fetch(name)
  raise "#{name}: persistence contract changed" unless service.fetch("volumes") == expected_binds
  raise "#{name}: privileged mode enabled" if service["privileged"]
  raise "#{name}: unexpected host namespace" if %w[host].include?(service["network_mode"])
  raise "#{name}: Docker socket exposed" if service.fetch("volumes").any? { |mount| mount.include?("docker.sock") }
end

cyberstrike_api = services.fetch("cyberstrike-api")
command = cyberstrike_api.fetch("command").join("\n")
raise "cyberstrike-api: API must bind to loopback" unless command.include?("--hostname 127.0.0.1")
raise "cyberstrike-api: wrong health route" unless cyberstrike_api.dig("healthcheck", "test").join(" ").include?("/global/health")
raise "cyberstrike-api: port 4096 must not be published" if cyberstrike_api.key?("ports")
unless cyberstrike_api.dig("environment", "CYBERSTRIKE_PERSISTENT_HOME") == "/opt/data/cyberstrike"
  raise "cyberstrike-api: CyberStrike state must use the persistent Hermes bind"
end

ports = services.fetch("workstation").fetch("ports")
unless ports.all? { |binding| binding.start_with?("127.0.0.1:") }
  raise "published ports must remain host-local"
end

malware = services.fetch("malware-lab")
raise "malware-lab: network must be disabled" unless malware["network_mode"] == "none"
raise "malware-lab: working directory must be /analysis" unless malware["working_dir"] == "/analysis"
raise "malware-lab: root must be read-only" unless malware["read_only"] == true
raise "malware-lab: all capabilities must be dropped" unless malware["cap_drop"] == ["ALL"]
unless malware.fetch("security_opt").include?("no-new-privileges:true")
  raise "malware-lab: no-new-privileges is missing"
end

expected_malware_volumes = [
  "malware-hermes-data:/opt/data",
  "malware-home:/home/hermes",
  "malware-analysis:/analysis"
]
unless malware.fetch("volumes") == expected_malware_volumes
  raise "malware-lab: storage must use only the isolated named volumes"
end

puts "Compose contract verification passed: merged anchors, NAT services, persistence, and malware isolation."
