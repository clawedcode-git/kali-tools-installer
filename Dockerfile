# syntax=docker/dockerfile:1
ARG BASE_IMAGE=archlinux:latest
FROM ${BASE_IMAGE}

LABEL maintainer="Kali Tools Installer Contributors"
LABEL description="Self-contained container for Kali Linux tools installation and testing"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install foundational dependencies based on package manager
RUN if command -v pacman >/dev/null 2>&1; then \
        pacman -Syu --noconfirm --needed bash sudo git curl ca-certificates base-devel; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && apt-get install -y --no-install-recommends bash sudo git curl ca-certificates build-essential; \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v dnf >/dev/null 2>&1; then \
        dnf install -y bash sudo git curl ca-certificates make gcc; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache bash sudo git curl ca-certificates build-base; \
    elif command -v zypper >/dev/null 2>&1; then \
        zypper --non-interactive install -y bash sudo git curl ca-certificates; \
    fi

# Create non-root user 'kali' with passwordless sudo for AUR and unprivileged execution
RUN if command -v useradd >/dev/null 2>&1; then \
        useradd -m -s /bin/bash -u 1000 kali; \
    else \
        adduser -D -s /bin/bash -u 1000 kali; \
    fi && \
    mkdir -p /etc/sudoers.d && \
    echo "kali ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kali && \
    chmod 0440 /etc/sudoers.d/kali

WORKDIR /kali-tools-installer

# Copy project files
COPY --chown=kali:kali . /kali-tools-installer/

# Ensure scripts are executable
RUN chmod +x /kali-tools-installer/install.sh \
             /kali-tools-installer/lib/*.sh \
             /kali-tools-installer/tests/*.sh

USER kali

ENTRYPOINT ["./install.sh"]
CMD ["--help"]
