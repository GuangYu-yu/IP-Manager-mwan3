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
https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chnroute_v6.txt
```

## cn4

```
https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chnroute.txt
```

## cmcc6

```
https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Mobile_v6.txt
```

## cnc6

```
https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Unicom_v6.txt
```

## ct6

```
https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Telecom_v6.txt
```

## cmcc4

```
https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Mobile_v4.txt
```

## cnc4

```
https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Unicom_v4.txt
```

## ct4

```
https://cdn.jsdelivr.net/gh/GuangYu-yu/chinaisp-cidr/China_Telecom_v4.txt
```

# 计划任务

```
0 15 * * * name="cmcc6"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 16 * * * name="cnc6"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 17 * * * name="ct6"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 18 * * * name="cmcc4"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 19 * * * name="cnc4"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 20 * * * name="ct4"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 21 * * * name="cf4"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
0 22 * * * name="cf6"; . /etc/config/nftset_configs/mwan3-nftset.sh; clear_and_update_nftset
```