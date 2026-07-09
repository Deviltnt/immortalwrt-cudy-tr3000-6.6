#!/bin/bash

# git clone -b openwrt-24.10-6.6 --single-branch --filter=blob:none https://github.com/padavanonly/immortalwrt-mt798x-24.10 immortalwrt-mt798x-24.10
# cd immortalwrt-mt798x-24.10

# Pin openwrt-mt798x to a commit that ships kernel 6.6.95 with a warp driver
# (package/mtk/drivers/warp) that still compiles against the bundled MTK WED
# register/macro set. The current branch head is 6.6.133 + 2025-06 warp, which
# fails with: 'WED_EX_INT_STA_FLD_TX_FBUF_HTH undeclared' etc.
# Last known-good: 5f78e5c4a4ae (kernel 6.6.95 bump, 2025-06-29).
#
# IMPORTANT: fetch the target commit by hash with depth=1 (NOT --unshallow, which
# would pull the entire 6+ GB repo history and hang the runner for hours).
#
# IMPORTANT 2: This script is invoked AFTER `cd openwrt` by the workflow
# (see .github/workflows/image-builder.yml, 'Load custom configuration' step),
# so the current working directory is already the openwrt tree. Use `.` instead
# of `openwrt` for `git -C` so we address THIS repo, not a non-existent
# openwrt/openwrt subdir.
#
# IMPORTANT 3: Print diagnostics so a future failure is visible in the log.
# Also wrap checkout in `|| true` so an unforeseen ref error never aborts
# the rest of the script under `set -e`.
#
# IMPORTANT 4: The workflow's `git clone -b openwrt-24.10-6.6 ...` does a
# depth=1 shallow clone of the REMOTE repo. That means the remote does NOT
# have arbitrary historical commits advertised in any ref, so a plain
# `git fetch --depth 1 origin <hash>` fails with:
#   fatal: remote error: upload-pack: not our ref <hash>
#   fatal: unable to read tree (<hash>)
# We must fetch with NO depth so git walks the ancestry from <hash> back to
# the shallow root, OR use a sufficiently large depth that reaches back to
# the commit's first parent.  The shortest commit-only fetch is unbounded
# depth on that single commit's history line:
#   git fetch --filter=blob:none origin <hash>
# This pulls just the commit/ tree objects along the ancestry (not blobs),
# which is small (a few MB) and ships the commit we need.
echo "[cudy-tr3000] cwd=$(pwd)"
echo "[cudy-tr3000] before-pin HEAD=$(git -C . rev-parse --short HEAD 2>/dev/null || echo unknown)"
KERNEL_PIN=5f78e5c4a4aebf79f56dc7de0ed0ecc96c1a37cf
if ! git -C . rev-parse --quiet --verify "$KERNEL_PIN^{commit}" >/dev/null 2>&1; then
    echo "[cudy-tr3000] fetching kernel pin $KERNEL_PIN (full ancestry, blobs excluded)"
    # First try a narrow fetch with a generous depth that should reach any
    # historical commit in this ~6-month-old repo.
    if ! git -C . fetch --depth 200 origin "$KERNEL_PIN" 2>&1; then
        echo "[cudy-tr3000] narrow fetch failed; falling back to commit-only fetch"
        git -C . fetch --filter=blob:none origin "$KERNEL_PIN"
    fi
fi
git -C . checkout "$KERNEL_PIN" || echo "[cudy-tr3000] WARN: checkout $KERNEL_PIN failed, continuing with current HEAD"
echo "[cudy-tr3000] after-pin  HEAD=$(git -C . rev-parse --short HEAD 2>/dev/null || echo unknown)"

# git config --local https.proxy socks5://host.docker.internal:1080

# ./scripts/feeds update -a
# ./scripts/feeds install -a

# theme
rm -rf feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# passwall
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 28.x feeds/packages/lang/golang

rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

rm -rf feeds/luci/applications/luci-app-passwall
# git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
git clone https://github.com/Openwrt-Passwall/openwrt-passwall2 package/passwall2-luci

# tailscale
# sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
# git clone https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# Modify default IP
sed -i 's/192.168.6.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# daede: kenzok8/openwrt-daede (replaces immortalwrt luci-app-daed)
# Pinned to release tag v2026.07.07 for reproducibility (main branch is mutable).
# Layout: package/kenzok8/openwrt-daede/{dae,daed,luci-app-daede}/ each ship a Makefile.
# We only enable the daed backend, so the dae/ subdir remains present but its package is not selected.
rm -rf package/kenzok8/openwrt-daede
git clone --depth 1 --branch v2026.07.07 https://github.com/kenzok8/openwrt-daede.git package/kenzok8/openwrt-daede

# Remove immortalwrt's official daed/luci-app-daed from feeds so the build does not
# also produce their packages (they conflict on /etc/config/daed UCI namespace).
rm -rf feeds/packages/net/daed
rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/luci/collections/luci-app-daed 2>/dev/null || true

# defconfig
# cp -f ../.config .config
# cp -f defconfig/mt7981-ax3000.config .config
sed -i 's|IMG_PREFIX:=|IMG_PREFIX:=$(shell TZ="Asia/Shanghai" date +"%Y%m%d")-24.10-6.6-|' include/image.mk
# make menuconfig

# compile and build
# make download -j8
# make -j$(nproc)