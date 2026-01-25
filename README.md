# Update-the-IPset

无需安装 mwan3 helper，直接通过终端管理 IPset，支持自动更新、持久化存储及开机自启。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/GuangYu-yu/Update-the-IPset-of-MWAN3-helper)

# 终端内首次运行

ipset
```
sh -c '
mkdir -p /etc/config/ipset_configs

cat > /etc/config/ipset_configs/vars.sh << "EOF"
#!/bin/sh
CFG_DIR="/etc/config/ipset_configs"

validate_input(){
  case "$name" in *[!a-zA-Z0-9_-]*|"") echo "无效的名称"; exit 1;; esac
  [ -n "$url" ] && case "$url" in http://*|https://*) ;; *) echo "无效的URL"; exit 1;; esac
  [ "$type" = 4 -o "$type" = 6 ] || { echo "无效的类型"; exit 1; }
}

download_file(){
  tgt=$1; src=$2; retries=3; count=0
  while [ $count -lt $retries ]; do
    wget -qO "$tgt" "$src" && [ -s "$tgt" ] && return 0
    count=$((count+1)); sleep 1
  done; return 1
}

add_ipset(){
  validate_input
  family="inet$([ "$type" -eq 6 ] && echo 6)"
  f=$CFG_DIR/${name}.txt; rm -f "$f"
  download_file "$f" "$url" || { echo "下载失败或文件为空"; exit 1; }
  ipset create "$name" hash:net family "$family" -exist
  ipset flush "$name"
  sed "s/^/add $name /" "$f" | ipset restore -!
  grep -v "^$name " $CFG_DIR/ipset_list > /tmp/ipset_list
  mv /tmp/ipset_list $CFG_DIR/ipset_list
  echo "$name $url $type" >> $CFG_DIR/ipset_list
}

clear_and_update_ipset(){
  f=$CFG_DIR/${name}.txt; : > "$f"
  grep "^$name " $CFG_DIR/ipset_list | awk "{print \$2, \$3}" | {
    read url type
    [ -z "$url" -o -z "$type" ] && { echo "未找到 URL 或 类型"; exit 1; }
    validate_input
    download_file "$f" "$url" || { echo "下载失败或文件为空"; exit 1; }
    ipset flush "$name"
    sed "s/^/add $name /" "$f" | ipset restore -!
  }
}
EOF

> /etc/config/ipset_configs/ipset_list

cat > /etc/init.d/ipset_load << "EOF"
#!/bin/sh /etc/rc.common

START=99
start() {
  . /etc/config/ipset_configs/vars.sh
  while IFS=" " read -r name url type; do
    family="inet$( [ "$type" -eq 6 ] && echo "6")"
    f=$CFG_DIR/${name}.txt
    [ -f "$f" ] && ipset create "$name" hash:net family "$family" -exist && \
    ipset flush "$name" && sed "s/^/add $name /" "$f" | ipset restore -!
  done < $CFG_DIR/ipset_list
}
EOF

chmod +x /etc/init.d/ipset_load
/etc/init.d/ipset_load enable
'
```

nftables
```
sh -c 'mkdir -p /etc/nftables_configs && cat << "EOF" > /etc/nftables_configs/vars.sh
#!/bin/sh
CFG_DIR="/etc/nftables_configs"

validate_input(){
  case "$name" in *[!a-zA-Z0-9_-]*|"") echo "无效的名称"; exit 1;; esac
  [ -n "$url" ] && case "$url" in http://*|https://*) ;; *) echo "无效的URL"; exit 1;; esac
  [ "$type" = 4 -o "$type" = 6 ] || { echo "无效的类型"; exit 1; }
}

download_file(){
  tgt=$1; src=$2; retries=3; count=0
  while [ $count -lt $retries ]; do
    wget -qO "$tgt" "$src" && [ -s "$tgt" ] && return 0
    count=$((count+1)); sleep 1
  done; return 1
}

add_nftables_set(){
  validate_input
  family="ip$([ "$type" -eq 6 ] && echo 6)"
  f=$CFG_DIR/${name}.txt; rm -f "$f"
  download_file "$f" "$url" || { echo "下载失败或文件为空"; exit 1; }
  nft add table $family filter 2>/dev/null || true
  nft delete set $family filter $name 2>/dev/null || true
  nft add set $family filter $name { type ${family}_addr\; flags interval\; auto-merge\; }
  nft flush set $family filter $name
  while read -r line; do [ -n "$line" ] && nft add element $family filter $name { $line }; done < "$f"
  grep -v "^$name " $CFG_DIR/nftables_list > /tmp/nftables_list
  mv /tmp/nftables_list $CFG_DIR/nftables_list
  echo "$name $url $type" >> $CFG_DIR/nftables_list
}

clear_and_update_nftables_set(){
  f=$CFG_DIR/${name}.txt; : > "$f"
  read url type < <(grep "^$name " $CFG_DIR/nftables_list | awk "{print \$2, \$3}")
  [ -z "$url" -o -z "$type" ] && { echo "未找到 URL 或 类型"; exit 1; }
  validate_input
  download_file "$f" "$url" || { echo "下载失败或文件为空"; exit 1; }
  family="ip$([ "$type" -eq 6 ] && echo 6)"
  nft flush set $family filter $name
  while read -r line; do [ -n "$line" ] && nft add element $family filter $name { $line }; done < "$f"
}
EOF

> /etc/nftables_configs/nftables_list

cat << "EOF" > /etc/init.d/nftables_load
#!/bin/sh /etc/rc.common
START=99
start(){
  . /etc/nftables_configs/vars.sh
  while IFS=" " read -r name url type; do
    family="ip$([ "$type" -eq 6 ] && echo 6)"
    f=$CFG_DIR/${name}.txt
    [ -f "$f" ] || continue
    nft add table $family filter 2>/dev/null
    nft add set $family filter $name { type ${family}_addr\; flags interval\; auto-merge\; } 2>/dev/null
    nft flush set $family filter $name
    while read -r line; do [ -n "$line" ] && nft add element $family filter $name { $line } 2>/dev/null; done < "$f"
  done < $CFG_DIR/nftables_list
}
EOF

chmod +x /etc/init.d/nftables_load
/etc/init.d/nftables_load enable'
```

创建 /etc/config/ipset_configs/vars.sh 目录。用于缓存IP段，会将IPset的IP段保存至对应的txt文件中。

创建 vars.sh 文件。之后写入相关变量和函数，用于后续命令来调用它们。

创建 ipset_list 文件。用于保存IPset名称，及其对应的URL

创建 /etc/init.d/ipset_load 文件。用于开机启动，并将缓存内的IP段导入到IPset之中。

# 添加IPset并导入

```
name="NAME"; url="URL"; type="IP"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

> 将`NAME`、`URL`、`IP`自定义。其中 `NAME` 对应IPset名称,只能包含字母（不区分大小写）、数字、下划线 (_) 和短横线 (-)。 `URL` 是其对应链接，必须以 `http://` 或 `https://` 开头。 `IP` 只能填写 `4` 或 `6` ，对应IPv4或IPv6。IP段被缓存在/etc/ipset_configs的txt文件之中

# 定时更新

后续只需要运行以下命令就可以更新IPset

```
name="NAME"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
```

> 只需要修改`NAME`即可

在命令前面加入（* * * * * ），就可以在计划任务中定期运行，注意空格位置

比如

```
0 20 * * * name="cn6"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
```

意味着每天`20`点自动更新`cn6`的IP段

# 命令

## cn6

```
name="cn6"; url="https://mirror.ghproxy.com/https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chnroute_v6.txt"; type="6"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## cmcc6

```
name="cmcc6"; url="https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Mobile_v6.txt"; type="6"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## cnc6

```
name="cnc6"; url="https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Unicom_v6.txt"; type="6"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## ct6

```
name="ct6"; url="https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Telecom_v6.txt"; type="6"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## cn4

```
name="cn4"; url="https://mirror.ghproxy.com/https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chnroute.txt"; type="4"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## cmcc4

```
name="cmcc4"; url="https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Mobile_v4.txt"; type="4"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## cnc4

```
name="cnc4"; url="https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Unicom_v4.txt"; type="4"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

## ct4

```
name="ct4"; url="https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Telecom_v4.txt"; type="4"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

# 计划任务

```
0 15 * * * name="cmcc6"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
0 16 * * * name="cnc6"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
0 17 * * * name="ct6"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
0 18 * * * name="cmcc4"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
0 19 * * * name="cnc4"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
0 20 * * * name="ct4"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
```

```
0 21 * * * name="cn6"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
0 22 * * * name="cn4"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
```
