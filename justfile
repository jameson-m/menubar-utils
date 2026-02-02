# menubar-utils justfile
# Run `just` to see available recipes

# Default recipe - show help
default:
    @just --list

# Configuration
swiftbar_plugins := "~/.swiftbar/plugins"
config_dir := "~/.config/menubar-utils"

# Build all plugins
build:
    cd claude-usage && go build -o claude-usage.1m.bin main.go

# Install plugins to SwiftBar
install: build
    @echo "Creating SwiftBar plugins directory..."
    mkdir -p {{swiftbar_plugins}}
    @echo "Linking plugins..."
    ln -sf "{{justfile_directory()}}/claude-usage/claude-usage.1m.bin" {{swiftbar_plugins}}/
    ln -sf "{{justfile_directory()}}/vitals/vitals.5s.swift" {{swiftbar_plugins}}/
    @echo "Setting up config directory..."
    mkdir -p {{config_dir}}
    @if [ ! -f {{config_dir}}/claude-usage.env ]; then \
        cp "{{justfile_directory()}}/claude-usage/.env.example" {{config_dir}}/claude-usage.env; \
        echo "Created {{config_dir}}/claude-usage.env - edit with your credentials"; \
    else \
        echo "Config already exists at {{config_dir}}/claude-usage.env"; \
    fi
    @echo "Done! Refresh SwiftBar to see plugins."

# Remove plugins from SwiftBar
uninstall:
    rm -f {{swiftbar_plugins}}/claude-usage.1m.bin
    rm -f {{swiftbar_plugins}}/vitals.5s.swift
    @echo "Plugins removed. Config preserved at {{config_dir}}/"

# Open config directory
config:
    open {{config_dir}}

# Clean build artifacts
clean:
    rm -f claude-usage/claude-usage.1m.bin

# Run tests (vitals output check)
test:
    @echo "Testing vitals..."
    ./vitals/vitals.5s.swift | head -5
    @echo ""
    @echo "Testing claude-usage..."
    ./claude-usage/claude-usage.1m.bin | head -5
