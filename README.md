# Usage

Add the following line to the `feeds.conf.default` file of your [OpenWrt SDK](http://archive.openwrt.org/barrier_breaker/14.07/ramips/mt7620a/) workspace:

```
src-git gocloud https://github.com/tsl0922/gocloud-openwrt-feeds.git
```

Then run:

```
scripts/feeds update -f gocloud
scripts/feeds install -a -p gocloud
```

Now, you will be able to see all the packages in this repository via `make menuconfig`.