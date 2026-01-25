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

add_ipset() {
    validate_input
    family="inet$([ "$type" -eq 6 ] && echo 6)"
    f=$CFG_DIR/${name}.txt
    rm -f "$f"

    download_file "$f" "$url" || {
        echo "下载失败或文件为空"
        exit 1
    }

    ipset create "$name" hash:net family "$family" -exist
    ipset flush "$name"
    sed "s/^/add $name /" "$f" | ipset restore -!

    grep -v "^$name " $CFG_DIR/ipset_list > /tmp/ipset_list
    mv /tmp/ipset_list $CFG_DIR/ipset_list
    echo "$name $url $type" >> $CFG_DIR/ipset_list
}

clear_and_update_ipset() {
    f=$CFG_DIR/${name}.txt
    : > "$f"

    grep "^$name " $CFG_DIR/ipset_list | awk '{print $2, $3}' | {
        read url type
        [ -z "$url" -o -z "$type" ] && {
            echo "未找到 URL 或 类型"
            exit 1
        }
        validate_input
        download_file "$f" "$url" || {
            echo "下载失败或文件为空"
            exit 1
        }
        ipset flush "$name"
        sed "s/^/add $name /" "$f" | ipset restore -!
    }
}
EOF

# 清空 ipset 列表文件
> /etc/config/ipset_configs/ipset_list

# 写入 init 启动脚本
cat << 'EOF' > /etc/init.d/ipset_load
#!/bin/sh /etc/rc.common
START=99

start() {
    . /etc/config/ipset_configs/vars.sh

    while IFS=" " read -r name url type; do
        family="inet$([ "$type" -eq 6 ] && echo 6)"
        f=$CFG_DIR/${name}.txt
        [ -f "$f" ] || continue
        ipset create "$name" hash:net family "$family" -exist
        ipset flush "$name"
        sed "s/^/add $name /" "$f" | ipset restore -!
    done < $CFG_DIR/ipset_list
}
EOF

# 赋予执行权限
chmod +x /etc/init.d/ipset_load

# 设置开机启动
/etc/init.d/ipset_load enable
