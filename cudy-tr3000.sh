#!/bin/bash

# git clone -b openwrt-24.10-6.6 --single-branch --filter=blob:none https://github.com/padavanonly/immortalwrt-mt798x-24.10 immortalwrt-mt798x-24.10
# cd immortalwrt-mt798x-24.10

# No kernel pin. We follow bnaand's known-good run #28489955216 which builds
# directly on upstream openwrt-24.10-6.6 HEAD (kernel 6.6.133 + warp, ABI OK).
# Earlier experiments pinning to 5f78e5c4 (kernel 6.6.95) failed because that
# commit is absent from the padavanonly remote (upload-pack: not our ref).

# git config --local https.proxy socks5://host.docker.internal:1080

# ./scripts/feeds update -a
# ./scripts/feeds install -a

# theme
rm -rf feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# golang 26.x (matches bnaand; 28.x has historically broken passwall2 feeds)
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# passwall2 dep packages (kept cloned so menuconfig remains coherent even
# though luci-app-passwall2 itself is NOT in our .config)
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

rm -rf feeds/luci/applications/luci-app-passwall
# git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
git clone https://github.com/Openwrt-Passwall/openwrt-passwall2 package/passwall2-luci

# tailscale (kept cloned to satisfy any leftover dep; not in our .config)
# sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
# git clone https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# daede: kenzok8/openwrt-daede (our choice over immortalwrt luci-app-daed)
rm -rf package/kenzok8/openwrt-daede
git clone --depth 1 --branch v2026.07.07 https://github.com/kenzok8/openwrt-daede.git package/kenzok8/openwrt-daede

# Remove immortalwrt's official daed/luci-app-daed from feeds so the build
# does not also produce their packages (would conflict on /etc/config/daed).
rm -rf feeds/packages/net/daed
rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/luci/collections/luci-app-daed 2>/dev/null || true

# Default LAN IP -> 192.168.2.1 (user requirement; was 192.168.10.1 in bnaand)
sed -i 's/192.168.6.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# defconfig + image prefix
# cp -f ../.config .config
# cp -f defconfig/mt7981-ax3000.config .config
sed -i 's|IMG_PREFIX:=|IMG_PREFIX:=$(shell TZ="Asia/Shanghai" date +"%Y%m%d")-24.10-6.6-|' include/image.mk
# make menuconfig

# compile and build
# make download -j8
# make -j$(nproc)