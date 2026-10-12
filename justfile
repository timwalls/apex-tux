# Build and install apex-tux as a systemd user service that starts with the
# graphical session. Override any variable on the command line, e.g.
#   just features=sysinfo,image bindir=$HOME/.local/bin install

features := "sysinfo"
bindir := home_directory() / "bin"
config_dir := config_directory() / "apex-tux"
unit_dir := config_directory() / "systemd/user"
unit := "apex-tux.service"

# List available recipes
default:
    @just --list

# Build the release binary
build:
    cargo build --release --features "{{features}}"

# Build, then install the binary, config and service, and (re)start it
install: build install-bin install-config install-service

# Install the binary into bindir
install-bin:
    install -Dm755 target/release/apex-tux "{{bindir}}/apex-tux"

# Install ./settings.toml, unless a config is already installed
install-config:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="{{config_dir}}/settings.toml"
    if [[ ! -e "$dest" ]]; then
        install -Dm644 settings.toml "$dest"
    elif ! cmp -s settings.toml "$dest"; then
        echo "Keeping existing $dest (differs from ./settings.toml; 'just update-config' replaces it)"
    fi

# Replace the installed config with ./settings.toml (keeps a backup)
update-config:
    install -Dm644 --backup=numbered settings.toml "{{config_dir}}/settings.toml"
    systemctl --user try-restart {{unit}}

# Install the systemd user unit, enable it and (re)start it
install-service:
    mkdir -p "{{unit_dir}}"
    sed 's|@BINARY@|{{bindir}}/apex-tux|' contrib/{{unit}} > "{{unit_dir}}/{{unit}}"
    systemctl --user daemon-reload
    systemctl --user enable {{unit}}
    systemctl --user restart {{unit}}

# Stop and remove the service and binary (leaves the config in place)
uninstall:
    -systemctl --user disable --now {{unit}}
    rm -f "{{unit_dir}}/{{unit}}" "{{bindir}}/apex-tux"
    systemctl --user daemon-reload

# Follow the service's log
logs:
    journalctl --user -u {{unit}} -f
