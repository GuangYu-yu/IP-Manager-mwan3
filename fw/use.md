置于 /etc/firewall.nft

/etc/config/firewall 添加
```
config include 'portguard'
	option type 'script'
	option path '/etc/firewall.nft'
```

```
fw4 reload
```

查看当前被挡住的扫描器（仍在前 10 秒窗口内）
```
nft list set inet portguard probe_v4 | awk '/elements/,/}/' | grep -v 'elements\|}'
```

查看已敲门通过的 IP（白名单）
```
nft list set inet portguard allow_v4 | awk '/elements/,/}/' | grep -v 'elements\|}'
```

查看已封禁的 IP
```
nft list set inet portguard ban_v4 | awk '/elements/,/}/' | grep -v 'elements\|}'
```