#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复 iStore (luci-app-store) 在 apk 架构下无法识别设备架构的问题
if [ -d "luci-app-store" ]; then
	echo " "
	sed -i 's|libc.control 2>/dev/null | head -1`|libc.control 2>/dev/null | head -1`; [ -z "$ARCH" ] \&\& [ -s "/etc/apk/arch" ] \&\& ARCH=`cat /etc/apk/arch`|' ./luci-app-store/root/bin/is-opkg
	echo "luci-app-store has been fixed!"
fi

# 修复 Turbo ACC 与 QCA NSS ECM (0600-1-qca-nss-ecm-support-CORE.patch) 的冲突
NSS_CORE_PATCH="$GITHUB_WORKSPACE/wrt/target/linux/qualcommax/patches-6.18/0600-1-qca-nss-ecm-support-CORE.patch"
if [ -f "$NSS_CORE_PATCH" ]; then
	echo "Fixing 0600-1-qca-nss-ecm-support-CORE.patch conflict with Turbo ACC..."
	python3 -c "
patch_path = '$NSS_CORE_PATCH'
with open(patch_path, 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if line.startswith('@@ -278,7 +278,6 @@ void nf_conntrack_register_notifier(stru'):
        lines[i] = '@@ -373,7 +373,6 @@ int nf_conntrack_register_notifier(struc\n'
        lines[i+5] = lines[i+5].replace('rcu_assign_pointer(net->ct.nf_conntrack_event_cb, new);', 'if (notify != NULL) {')
        lines[i+6] = lines[i+6].replace('mutex_unlock(\&nf_ct_ecache_mutex);', '\tret = -EBUSY;')
        lines[i+7] = lines[i+7].replace('}', '\tgoto out_unlock;')
        break
with open(patch_path, 'w') as f:
    f.writelines(lines)
"
	echo "Qualcomm NSS core patch conflict has been fixed!"
fi

# 修复 Turbo ACC SFE 补丁 (953-net-patch-linux-kernel-to-support-shortcut-fe.patch) 在 NSS 平台下重复定义 br_dev_update_stats 的问题
for kv in "6.18" "6.12" "6.6"; do
	SFE_PATCH="$GITHUB_WORKSPACE/wrt/target/linux/generic/hack-$kv/953-net-patch-linux-kernel-to-support-shortcut-fe.patch"
	if [ -f "$SFE_PATCH" ] && [ -f "$NSS_CORE_PATCH" ]; then
		echo "Fixing SFE patch $kv to avoid br_dev_update_stats redefinition with NSS..."
		python3 -c "
patch_path = '$SFE_PATCH'
with open(patch_path, 'r') as f:
    content = f.read()
start_idx = content.find('--- a/net/bridge/br_if.c')
end_idx = content.find('--- a/net/core/dev.c')
if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + content[end_idx:]
    with open(patch_path, 'w') as f:
        f.write(new_content)
"
	fi
done

# 修复 lua-maxminddb 下载 Hash 校验失败的问题
MAXMINDDB_MAKEFILE="./lua-maxminddb/Makefile"
if [ -f "$MAXMINDDB_MAKEFILE" ]; then
	echo "Fixing lua-maxminddb Makefile mirror hash..."
	sed -i 's/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/g' "$MAXMINDDB_MAKEFILE"
fi

# 修复 rblibtorrent 中的 boost-version.mk 导致的 find 慢/挂起问题
BOOST_VERSION_MK="./luci-app-qbittorrent/rblibtorrent/boost-version.mk"
if [ -f "$BOOST_VERSION_MK" ]; then
	echo "Fixing rblibtorrent boost-version.mk..."
	sed -i 's|BOOST_MAKEFILE := .*|BOOST_MAKEFILE := \$(TOPDIR)/feeds/packages/libs/boost/Makefile|g' "$BOOST_VERSION_MK"
fi

# 修复 pdnsd-alt 下载 Hash 校验失败的问题
PDNSD_ALT_MAKEFILE="./pdnsd-alt/Makefile"
if [ -f "$PDNSD_ALT_MAKEFILE" ]; then
	echo "Fixing pdnsd-alt Makefile mirror hash..."
	sed -i 's/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/g' "$PDNSD_ALT_MAKEFILE"
fi





