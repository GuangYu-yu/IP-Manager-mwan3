#!/bin/sh

mkdir -p /etc/config/ipset_configs

cat << 'SHEOF' > /etc/config/ipset_configs/vars.sh
#!/bin/sh

CFG_DIR="/etc/config/ipset_configs"

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

update_ipset_common() {
    name=$1; f=$2; type=$3
    family="inet$([ "$type" -eq 6 ] && echo 6)"
    tmp="${name}_tmp"

    ipset create "$name" hash:net family "$family" -exist 2>/dev/null
    ipset create "$tmp" hash:net family "$family" -exist 2>/dev/null || return 1
    ipset flush "$tmp"

    sed "s/^/add $tmp /" "$f" | ipset restore -! || { ipset destroy "$tmp"; return 1; }

    ipset swap "$name" "$tmp"
    ipset destroy "$tmp"
    ipset save > /etc/ipset.conf
}

add_ipset() {
    validate_input
    f=$CFG_DIR/${name}.txt; rm -f "$f"

    if ! download_file "$f" "$url"; then echo "下载失败或文件为空"; rm -f "$f"; exit 1; fi

    filter_file "$f"
    [ -s "$f" ] || { echo "文件内容无效"; rm -f "$f"; exit 1; }

    if update_ipset_common "$name" "$f" "$type"; then
        sed -i "/^$name /d" "$CFG_DIR/ipset_list" 2>/dev/null || true
        echo "$name $url $type" >> "$CFG_DIR/ipset_list"
    else
        exit 1
    fi
}

clear_and_update_ipset() {
    f=$CFG_DIR/${name}.txt; : > "$f"
    set -- $(grep "^$name " "$CFG_DIR/ipset_list")
    [ -z "$1" ] && { echo "未找到配置: $name"; exit 1; }
    url=$2; type=$3

    if ! download_file "$f" "$url"; then echo "下载失败或文件为空"; rm -f "$f"; exit 1; fi
    filter_file "$f"
    [ -s "$f" ] || { echo "文件内容无效"; rm -f "$f"; exit 1; }
    update_ipset_common "$name" "$f" "$type"
}
SHEOF

> /etc/config/ipset_configs/ipset_list
/etc/init.d/ipset enable
/etc/init.d/ipset start