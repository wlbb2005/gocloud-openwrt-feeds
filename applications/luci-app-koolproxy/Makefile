include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-koolproxy
PKG_VERSION:=3.8.4
PKG_RELEASE:=4

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-koolproxy
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI support for koolproxy
	DEPENDS:=+ipset +iptables-mod-nat-extra
endef

define Build/Prepare
	cp ./koolproxy/$(ARCH) $(PKG_BUILD_DIR)/koolproxy

	mkdir -p $(PKG_BUILD_DIR)/rules
	cp ./koolproxy/rules/* $(PKG_BUILD_DIR)/rules
endef

define Build/Compile
endef

define Package/luci-app-koolproxy/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
     /etc/init.d/koolproxy disable
     /etc/init.d/koolproxy stop
fi
exit 0
endef

define Package/luci-app-koolproxy/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	( . /etc/uci-defaults/luci-koolproxy ) && rm -f /etc/uci-defaults/luci-koolproxy
	rm -f /tmp/luci-indexcache
	chmod 755 /etc/init.d/koolproxy >/dev/null 2>&1
	/etc/init.d/koolproxy enable >/dev/null 2>&1
fi
exit 0
endef

define Package/luci-app-koolproxy/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	cp -pR ./luasrc/* $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/
	cp -pR ./root/* $(1)/

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/koolproxy $(1)/usr/share/koolproxy/koolproxy
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/rules/user.txt $(1)/usr/share/koolproxy/data/
	$(INSTALL_DIR) $(1)/usr/share/koolproxy/data/rules
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/rules/* $(1)/usr/share/koolproxy/data/rules/
endef

$(eval $(call BuildPackage,luci-app-koolproxy))
