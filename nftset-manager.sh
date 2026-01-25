#!/bin/sh

# 创建配置目录
mkdir -p /etc/config/nftables_configs

# 写入 vars.sh
cat << 'EOF' > /etc/config/nftables_configs/vars.sh
#!/bin/sh

CFG_DIR="/etc/config/nftables_configs"

validate_input() {
    case "$name" in *[!a-zA-Z0-9_-]*|"") echo "无效的名称"; exit 1;; esac
    [ -n "$url" ] && case "$url" in http://*|https://*) ;; *) echo "无效的URL"; exit 1;; esac
    [ "$type" = 4 ] || [ "$type" = 6 ] || { echo "无效的类型"; exit 1; }
}

download_file() {
    tgt=$1; src=$2; retries=3; count=0
    while [ $count -lt $retries ]; do
        wget -qO "$tgt" "$src" && [ -s "$tgt" ] && return 0
        count=$((count+1))
        sleep 1
    done
    return 1
}

add_nftables_set() {
    validate_input
    family="ip$([ "$type" -eq 6 ] && echo 6)"
    f=$CFG_DIR/${name}.txt
    rm -f "$f"
    download_file "$f" "$url" || { echo "下载失败或文件为空"; exit 1; }

    # 创建表和集合
    nft add table "$family" filter 2>/dev/null || true
    nft delete set "$family" filter "$name" 2>/dev/null || true
    nft add set "$family" filter "$name" "{ type ${family}_addr; flags interval; auto-merge; }"

    # 添加IP元素
    nft flush set "$family" filter "$name"
    while read -r line; do
        [ -n "$line" ] && nft add element "$family" filter "$name" "{ $line }"
    done < "$f"

    # 更新列表
    grep -v "^$name " "$CFG_DIR/nftables_list" > /tmp/nftables_list
    mv /tmp/nftables_list "$CFG_DIR/nftables_list"
    echo "$name $url $type" >> "$CFG_DIR/nftables_list"
}

clear_and_update_nftables_set() {
    f=$CFG_DIR/${name}.txt
    : > "$f"
    grep "^$name " "$CFG_DIR/nftables_list" | awk '{print $2, $3}' | {
        read url type
        [ -z "$url" ] || [ -z "$type" ] && { echo "未找到 URL 或 类型"; exit 1; }
        validate_input
        download_file "$f" "$url" || { echo "下载失败或文件为空"; exit 1; }
        family="ip$([ "$type" -eq 6 ] && echo 6)"
        nft flush set "$family" filter "$name"
        while read -r line; do
            [ -n "$line" ] && nft add element "$family" filter "$name" "{ $line }"
        done < "$f"
    }
}
EOF

# 清空列表文件
> /etc/config/nftables_configs/nftables_list

# 写入 init 脚本
cat << 'EOF' > /etc/init.d/nftables_load
#!/bin/sh /etc/rc.common

START=99

start() {
    . /etc/config/nftables_configs/vars.sh
    while IFS=" " read -r name url type; do
        f=$CFG_DIR/${name}.txt
        [ -f "$f" ] || continue

        family="ip$([ "$type" -eq 6 ] && echo 6)"
        nft add table "$family" filter 2>/dev/null || true
        nft add set "$family" filter "$name" "{ type ${family}_addr; flags interval; auto-merge; }" 2>/dev/null
        nft flush set "$family" filter "$name"

        while read -r line; do
            [ -n "$line" ] && nft add element "$family" filter "$name" "{ $line }" 2>/dev/null
        done < "$f"
    done < "$CFG_DIR/nftables_list"
}
EOF

# 设置权限并开机启动
chmod +x /etc/init.d/nftables_load
/etc/init.d/nftables_load enable
