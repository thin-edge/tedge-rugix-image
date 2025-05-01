# System image. Default to amd64 if the arch does not match
DEFAULT_SYSTEM := if arch() == "aarch64" {
    "tedge-debian-12-efi-arm64"
} else if arch() == "x86_64"  {
    "tedge-debian-12-efi-amd64"
} else {
    "tedge-debian-12-efi-amd64"
}

SYSTEM := env("SYSTEM", DEFAULT_SYSTEM)

# Default version (info only)
export VERSION := env_var_or_default("VERSION", `date +'%Y%m%d.%H%M'`)

# Release version id (combined name and version)
export RELEASE_ID := env_var_or_default("RELEASE_ID", SYSTEM + "_" + VERSION)

# Use ipv6 network on the host so it does not conflict with the docker in docker inside the VM
# See https://github.com/silitics/rugix/issues/49
DOCKER_NETWORK := "rugix-net"
DOCKER_FLAGS := "--network=" + DOCKER_NETWORK

# Generate a version name (that can be used in follow up commands)
generate_version:
    @echo "{{VERSION}}"

prepare:
    #!/usr/bin/env bash
    if [ ! -f tests/id_rsa ]; then
        mkdir -p tests
        ssh-keygen -t rsa -b 4096 -f tests/id_rsa -q -N ""
    fi

    PUB_KEY="SSH_KEYS_ci=\"$(cat tests/id_rsa.pub)\""
    if grep -q "SSH_KEYS_ci=" .env; then
        echo ".env already contains testing public key"
    else
        echo "$PUB_KEY" >> .env
    fi

    docker network inspect {{DOCKER_NETWORK}} >/dev/null 2>&1 || docker network create --ipv6 -o com.docker.network.enable_ipv4=false {{DOCKER_NETWORK}}

# list available systems that can be built
list-systems:
    ./run-bakery list systems

    @echo
    @echo just SYSTEM=example build-image
    @echo

# Install cross-platform tools
build-setup:
    docker run --privileged --rm tonistiigi/binfmt --install all

# Build an image
# Note: use default output and rename later. see https://github.com/silitics/rugix/issues/53
build-image: build-setup
    ./run-bakery bake image \
        --release-id "{{RELEASE_ID}}" \
        --release-version "{{VERSION}}" \
        {{SYSTEM}}

# Build bundle (uncompressed)
build-bundle-uncompressed OUTPUT="system.rugixb": build-setup
    ./run-bakery bake bundle \
        --release-id "{{RELEASE_ID}}" \
        --release-version "{{VERSION}}" \
        --without-compression \
        {{SYSTEM}} \
        build/{{SYSTEM}}/{{OUTPUT}}

# Build build (compressed)
build-bundle OUTPUT="system.rugixb": build-setup
    ./run-bakery bake bundle \
        --release-id "{{RELEASE_ID}}" \
        --release-version "{{VERSION}}" \
        {{SYSTEM}} \
        build/{{SYSTEM}}/{{OUTPUT}}

# Start vm
start-vm: prepare
    DOCKER_FLAGS="{{DOCKER_FLAGS}}" ./run-bakery run \
        --release-id "{{RELEASE_ID}}" \
        --release-version "{{VERSION}}" \
        {{SYSTEM}} ||:

# Connect to vm
connect-vm:
    [ -f ./tests/id_rsa ] && ssh-add ./tests/id_rsa
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@127.0.0.1

#
# Publishing
#
# Publish latest image to Cumulocity
publish:
    cd {{justfile_directory()}} && ./scripts/upload-c8y.sh

# Publish a given github release to Cumulocity (using external urls)
publish-external tag *args="":
    cd {{justfile_directory()}} && ./scripts/c8y-publish-release.sh {{tag}} {{args}}

# Publish a given github release to Cumulocity (using external urls) but convert an existing draft to a prerelease beforehand
publish-external-prerelease tag:
    cd {{justfile_directory()}} && ./scripts/c8y-publish-release.sh {{tag}} --pre-release

# Trigger a release (by creating a tag)
release:
    git tag -a "{{VERSION}}" -m "{{VERSION}}"
    git push origin "{{VERSION}}"
    @echo
    @echo "Created release (tag): {{VERSION}}"
    @echo