#!/usr/bin/env bash
set -euo pipefail

# This script manages sysctl settings by applying composable profiles.
# The settings for each component are stored in heredocs for clarity
# and portability, removing the need for separate snippet files.

# The final, managed configuration file that this script will create.
SYSCTL_PROFILE_CONF="/etc/sysctl.d/10-sysctl-profile.conf"

# -----------------------------------------------------------------------------
# HEREDOC DEFINITIONS: Sysctl setting "snippets" are defined here.
# -----------------------------------------------------------------------------

# <<< MODIFIED >>> Contains expanded security hardening settings.
# Lynis  [KRNL-5820] if not required, consider explicit disabling of core dump in /etc/security/limits.conf file
read -r -d '' BASE_SECURITY <<'EOF'
# --- Base Security Settings ---
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
fs.protected_fifos = 2
fs.protected_regular = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
kernel.perf_event_paranoid = 3
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false
dev.tty.ldisc_autoload = 0
EOF

# <<< MODIFIED >>> Contains expanded settings for virtual machine environments.
read -r -d '' VM_TUNING <<'EOF'
# --- Virtual Memory & Swap Management ---
vm.swappiness = 2
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.max_map_count = 262144
vm.overcommit_memory = 1
vm.zone_reclaim_mode = 0
vm.dirty_bytes = 33554432
vm.dirty_background_bytes = 16777216
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.oom_kill_allocating_task = 0
EOF

# <<< MODIFIED >>> Contains expanded network stack settings.
read -r -d '' NETWORK_HEAVY <<'EOF'
# --- High-Performance Network Tuning ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 2048
net.ipv4.tcp_max_syn_backlog = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_tw_reuse = 1
net.core.netdev_max_backlog = 16384
net.core.optmem_max = 65536
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.tcp_mtu_probing = 1
EOF

# <<< NEW >>> Contains TCP Keepalive settings.
read -r -d '' TCP_KEEPALIVE <<'EOF'
# --- TCP Keepalive Optimization ---
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5
EOF

# <<< NEW >>> Contains File System and I/O settings.
read -r -d '' FS_IO_TUNING <<'EOF'
# --- File System and I/O Optimization ---
fs.file-max = 2097152
fs.may_detach_mounts = 1
fs.inotify.max_queued_events = 1048576
fs.aio-max-nr = 1048576
EOF

# <<< NEW >>> Contains Kernel resource management settings.
read -r -d '' KERNEL_RESOURCES <<'EOF'
# --- Kernel Resource Management ---
kernel.pid_max = 4194304
kernel.threads-max = 4194304
kernel.keys.root_maxkeys = 1000000
kernel.keys.root_maxbytes = 25000000
kernel.panic_on_oom = 0
kernel.printk = 3 4 1 3
EOF

# <<< NEW >>> Contains Inter-Process Communication (IPC) settings.
read -r -d '' IPC_TUNING <<'EOF'
# --- Inter-Process Communication Settings ---
kernel.msgmax = 65536
kernel.msgmnb = 65536
kernel.msgmni = 32768
kernel.sem = 250 256000 32 1024
kernel.shmall = 33554432
kernel.shmmax = 68719476736
EOF

# <<< NEW >>> Contains IPv6 disabling settings.
read -r -d '' IPV6_DISABLE <<'EOF'
# --- IPv6 Disabling ---
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

# <<< MODIFIED >>> Contains expanded settings for hosting Docker/containers.
read -r -d '' DOCKER_HOST <<'EOF'
# --- Docker & Container Host Tuning ---
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
kernel.unprivileged_userns_clone = 1
user.max_user_namespaces = 15000
EOF

# -----------------------------------------------------------------------------
# FUNCTION: Applies a sysctl profile by composing the snippets defined above.
# -----------------------------------------------------------------------------
apply_sysctl_profile() {
    local profile="$1"
    echo -e "\n⚙️ Applying sysctl profile: $profile"

    local -a snippets_to_apply=()

    case "$profile" in
        virtual-docker-host)
            # <<< MODIFIED >>> This profile now includes all new and updated snippets.
            echo "Building profile from all available tuning snippets..."
            snippets_to_apply=(
                BASE_SECURITY
                VM_TUNING
                NETWORK_HEAVY
                TCP_KEEPALIVE
                FS_IO_TUNING
                KERNEL_RESOURCES
                IPC_TUNING
                DOCKER_HOST
                IPV6_DISABLE
            )
            ;;

        physical-web-server)
            echo "Building profile from: BASE_SECURITY, NETWORK_HEAVY, TCP_KEEPALIVE, FS_IO_TUNING"
            snippets_to_apply=(
                BASE_SECURITY
                NETWORK_HEAVY
                TCP_KEEPALIVE
                FS_IO_TUNING
            )
            ;;

        minimal-vm)
            echo "Building profile from: BASE_SECURITY, VM_TUNING"
            snippets_to_apply=(
                BASE_SECURITY
                VM_TUNING
            )
            ;;
        *)
            echo "❌ Unknown sysctl profile: '$profile'. No changes made."
            return 1
            ;;
    esac

    {
        echo "# This file is auto-generated by a script. DO NOT EDIT MANUALLY."
        echo "# Profile applied: $profile on $(date)"
        echo ""
    } > "$SYSCTL_PROFILE_CONF"

    for snippet_var in "${snippets_to_apply[@]}"; do
        echo "  -> Appending settings from $snippet_var"
        printf '%s\n\n' "${!snippet_var}" >> "$SYSCTL_PROFILE_CONF"
    done

    echo "✅ Sysctl profile file created at $SYSCTL_PROFILE_CONF"
    echo "Applying new sysctl settings..."
    sysctl --system
    echo "Sysctl profile application complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "${1-}" ]]; then
        echo "Usage: $0 <profile_name>"
        echo "Available profiles: virtual-docker-host, physical-web-server, minimal-vm"
        exit 1
    fi
    apply_sysctl_profile "$1"
fi