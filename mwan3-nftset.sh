#!/bin/sh

CFG_DIR="/etc/config/nftset_configs"

# 创建配置目录
mkdir -p "$CFG_DIR"

# 写入 nftset 管理脚本
cat << 'SHEOF' > "$CFG_DIR/mwan3-nftset.sh"
#!/bin/sh

CFG_DIR="__CFG_DIR__"
NFT_TABLE="mwan3"

validate_input() {
	case "$name" in *[!a-zA-Z0-9_-]*|"") echo "无效的名称"; exit 1 ;; esac
	[ -n "$url" ] && case "$url" in http://*|https://*) ;; *) echo "无效的URL"; exit 1 ;; esac
	[ "$type" = 4 -o "$type" = 6 ] || { echo "无效的类型"; exit 1; }
}

download_file() {
	tgt=$1; src=$2; retries=3; count=0
	while [ $count -lt $retries ]; do
		wget -qO "$tgt" "$src" && [ -s "$tgt" ] && return 0
		count=$((count + 1)); sleep 1
	done
	return 1
}

filter_file() {
	sed -i -e '/^[[:space:]]*$/d' -e '/[^0-9a-fA-F:.\/]/d' "$1"
}

nft_family() {
	[ "$1" -eq 6 ] && echo "ipv6_addr" || echo "ipv4_addr"
}

update_nftset() {
	name=$1; f=$2; type=$3
	fam=$(nft_family "$type")
	tmpfile="/tmp/nftset_${name}.nft"

	nft add set inet "$NFT_TABLE" "$name" \
		"{ type $fam; flags interval; auto-merge; }" 2>/dev/null || true

	{
		echo "flush set inet $NFT_TABLE $name"
		if [ -s "$f" ]; then
			echo "add element inet $NFT_TABLE $name {"
			awk '{printf "%s,\n", $0}' "$f"
			echo "}"
		fi
	} > "$tmpfile"

	nft -f "$tmpfile"
	rc=$?
	rm -f "$tmpfile"
	return $rc
}

add_nftset() {
	validate_input
	mkdir -p "$CFG_DIR"
	nft add table inet "$NFT_TABLE" 2>/dev/null || true

	f=$CFG_DIR/${name}.txt
	rm -f "$f"

	if ! download_file "$f" "$url"; then
		echo "下载失败或文件为空"; rm -f "$f"; exit 1
	fi

	filter_file "$f"
	[ -s "$f" ] || { echo "文件内容无效"; rm -f "$f"; exit 1; }

	if update_nftset "$name" "$f" "$type"; then
		grep -v "^$name " "$CFG_DIR/nftset_list" > /tmp/nftset_list 2>/dev/null || true
		mv /tmp/nftset_list "$CFG_DIR/nftset_list" 2>/dev/null || true
		echo "$name $url $type" >> "$CFG_DIR/nftset_list"
	else
		exit 1
	fi
}

clear_and_update_nftset() {
	mkdir -p "$CFG_DIR"
	f=$CFG_DIR/${name}.txt; : > "$f"
	info=$(grep "^$name " "$CFG_DIR/nftset_list")
	[ -z "$info" ] && { echo "未找到配置: $name"; exit 1; }
	url=$(echo "$info" | awk '{print $2}')
	type=$(echo "$info" | awk '{print $3}')

	if ! download_file "$f" "$url"; then
		echo "下载失败或文件为空"; rm -f "$f"; exit 1
	fi
	filter_file "$f"
	[ -s "$f" ] || { echo "文件内容无效"; rm -f "$f"; exit 1; }
	update_nftset "$name" "$f" "$type"
}
SHEOF

# 替换占位符
sed -i "s|__CFG_DIR__|$CFG_DIR|g" "$CFG_DIR/mwan3-nftset.sh"

# 清空 nftset 列表文件
> "$CFG_DIR/nftset_list"

echo "mwan3-nftset 管理脚本已安装到 $CFG_DIR/"
echo ""
echo "用法:"
echo "  name=\"名称\"; url=\"URL\"; type=\"4|6\"; . $CFG_DIR/mwan3-nftset.sh; add_nftset"
echo "  name=\"名称\"; . $CFG_DIR/mwan3-nftset.sh; clear_and_update_nftset"