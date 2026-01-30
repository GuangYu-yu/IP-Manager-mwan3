#!/bin/sh

# 创建配置目录
mkdir -p /etc/config/ipset_configs

# 写入 vars.sh 脚本
cat << 'EOF' > /etc/config/ipset_configs/vars.sh
#!/bin/sh

CFG_DIR="/etc/config/ipset_configs"

validate_input() {
    case "$name" in
        *[!a-zA-Z0-9_-]*|"")
            echo "无效的名称"
            exit 1
            ;;
    esac

    [ -n "$url" ] && case "$url" in
        http://*|https://*)
            ;;
        *)
            echo "无效的URL"
            exit 1
            ;;
    esac

    [ "$type" = 4 -o "$type" = 6 ] || {
        echo "无效的类型"
        exit 1
        ;;
    }
}

download_file() {
    tgt=$1
    src=$2
    retries=3
    count=0

    while [ $count -lt $retries ]; do
        wget -qO "$tgt" "$src" && [ -s "$tgt" ] && return 0
        count=$((count + 1))
        sleep 1
    done

    return 1
}

filter_file() {
    f=$1
    # 删除空行和包含非法字符的行
    sed -i -e '/^[[:space:]]*$/d' -e '/[^0-9a-fA-F:\.\/]/d' "$f"
}

update_ipset_common() {
    name=$1
    f=$2
    type=$3
    
    family="inet$([ "$type" -eq 6 ] && echo 6)"
    tmp_name="${name}_tmp"
    
    # 确保清理可能存在的残留临时集合
    ipset destroy "$tmp_name" >/dev/null 2>&1
    
    ipset create "$name" hash:net family "$family" -exist
    if ! ipset create "$tmp_name" hash:net family "$family" -exist; then
         echo "创建临时集合失败"
         return 1
    fi
    
    ipset flush "$tmp_name"
    
    if ! sed "s/^/add $tmp_name /" "$f" | ipset restore -!; then
        echo "恢复 ipset 失败，正在清理..."
        ipset destroy "$tmp_name"
        return 1
    fi
    
    ipset swap "$name" "$tmp_name"
    ipset destroy "$tmp_name"
    
    # 使用 ipset save 进行持久化
    ipset save > /etc/ipset.conf
}

add_ipset() {
    validate_input
    f=$CFG_DIR/${name}.txt
    rm -f "$f"

    if ! download_file "$f" "$url"; then
        echo "下载失败或文件为空"
        rm -f "$f"
        exit 1
    fi
    
    filter_file "$f"
    if [ ! -s "$f" ]; then
        echo "文件内容无效（为空或包含非法字符）"
        rm -f "$f"
        exit 1
    fi

    if update_ipset_common "$name" "$f" "$type"; then
        grep -v "^$name " $CFG_DIR/ipset_list > /tmp/ipset_list
        mv /tmp/ipset_list $CFG_DIR/ipset_list
        echo "$name $url $type" >> $CFG_DIR/ipset_list
    else
        exit 1
    fi
}

clear_and_update_ipset() {
    f=$CFG_DIR/${name}.txt
    : > "$f"

    info=$(grep "^$name " $CFG_DIR/ipset_list)
    if [ -z "$info" ]; then
        echo "未找到配置: $name"
        exit 1
    fi
    
    url=$(echo "$info" | awk '{print $2}')
    type=$(echo "$info" | awk '{print $3}')
    
    if ! download_file "$f" "$url"; then
        echo "下载失败或文件为空"
        rm -f "$f"
        exit 1
    fi
    
    filter_file "$f"
    if [ ! -s "$f" ]; then
        echo "文件内容无效（为空或包含非法字符）"
        rm -f "$f"
        exit 1
    fi
    
    update_ipset_common "$name" "$f" "$type"
}
EOF

# 清空 ipset 列表文件
> /etc/config/ipset_configs/ipset_list

# 启用并启动系统 ipset 服务
/etc/init.d/ipset enable
/etc/init.d/ipset start