# IP-Manager-mwan3

无需安装 mwan3 helper，支持自动更新、持久化及开机启动。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/GuangYu-yu/IP-Manager-mwan3)

# 终端内首次运行

ipset
```
curl -fsSL https://gitee.com/zhxdcyy/sh/raw/master/ipset.sh | sh
```

nftset
```
curl -fsSL https://gitee.com/zhxdcyy/sh/raw/master/nftset.sh | sh
```

# 添加并导入

ipset
```
name="NAME"; url="URL"; type="4|6"; . /etc/config/ipset_configs/vars.sh; add_ipset
```

nftset
```
name="NAME"; url="URL"; type="4|6"; . /etc/config/nftset_configs/vars.sh; add_nftset
```

> 将`NAME`、`URL`、`4|6`自定义。其中 `NAME` 对应名称,只能包含字母（不区分大小写）、数字、下划线 (_) 和短横线 (-)。 `URL` 是其对应链接，必须以 `http://` 或 `https://` 开头。 `4|6` 只能填写 `4` 或 `6` ，对应IPv4或IPv6

# 定时更新

后续只需要运行以下命令就可以更新

ipset
```
name="NAME"; . /etc/config/ipset_configs/vars.sh; clear_and_update_ipset
```

nftset
```
name="NAME"; . /etc/config/nftset_configs/vars.sh; clear_and_update_nftset
```

> 只需要修改`NAME`即可，推荐添加到计划任务

# CIDR

## cn6

```
https://china-operator-ip.yfgao.com/china6.txt
```

## cn4

```
https://china-operator-ip.yfgao.com/china.txt
```

## cmcc6

```
https://china-operator-ip.yfgao.com/cmcc6.txt
```

## cnc6

```
https://china-operator-ip.yfgao.com/unicom6.txt
```

## ct6

```
https://china-operator-ip.yfgao.com/chinanet6.txt
```

## cmcc4

```
https://china-operator-ip.yfgao.com/cmcc.txt
```

## cnc4

```
https://china-operator-ip.yfgao.com/unicom.txt
```

## ct4

```
https://china-operator-ip.yfgao.com/chinanet.txt
```

# 计划任务

```
0 15 * * * for name in cmcc6 cnc6 ct6 cmcc4 cnc4 ct4 cf4 cf6; do name="$name" . /etc/config/nftset_configs/vars.sh; clear_and_update_nftset; done
```