local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"

local o,t,e
local v=luci.sys.exec("/usr/share/koolproxy/koolproxy -v")
local s=luci.sys.exec("head -3 /usr/share/koolproxy/data/rules/koolproxy.txt | grep rules | awk -F' ' '{print $3,$4}'")
local u=luci.sys.exec("head -4 /usr/share/koolproxy/data/rules/koolproxy.txt | grep video | awk -F' ' '{print $3,$4}'")
local h=luci.sys.exec("grep -v '^!' /usr/share/koolproxy/data/rules/user.txt | wc -l")
local i=luci.sys.exec("cat /usr/share/koolproxy/dnsmasq.adblock | wc -l")
local arptable=luci.sys.net.arptable() or {}

if luci.sys.call("pidof koolproxy >/dev/null") == 0 then
	status = translate("<font color=\"green\">运行中</font>")
else
	status = translate("<font color=\"red\">未运行</font>")
end

o = Map("koolproxy", translate("KoolProxy"), translate("KoolProxy 是能识别 Adblock 规则的代理软件，可以过滤普通网页广告、视频广告、HTTPS 广告<br />Adblock Plus 的 Host 列表 + KoolProxy 黑名单模式运行更流畅上网体验，开启全局模式获取更好的过滤效果"))
o.redirect = luci.dispatcher.build_url("admin/network/koolproxy")

t = o:section(TypedSection, "global")
t.anonymous = true
t.description = translate(string.format("程序版本: <strong>%s</strong>, 运行状态：<strong>%s</strong><br />", v, status))

t:tab("base",translate("基本设置"))

e = t:taboption("base", Flag, "enabled", translate("启用"))
e.default = 0
e.rmempty = false

e = t:taboption("base", Value, "startup_delay", translate("启动延时"))
e:value(0, translate("不延时"))
for _, v in ipairs({5, 10, 15, 25, 40}) do
	e:value(v, translate("%u 秒") %{v})
end
e.datatype = "uinteger"
e.default = 0
e.rmempty = false

e = t:taboption("base", ListValue, "koolproxy_mode", translate("过滤模式"))
e.default = 1
e.rmempty = false
e:value(1, translate("全局模式"))
e:value(2, translate("IPSET模式"))

e = t:taboption("base", MultiValue, "koolproxy_rules", translate("内置规则"))
e.optional = false
e.rmempty = false
e:value("koolproxy.txt", translate(string.format("静态规则: <font color=\"green\">%s</font>", s)))
e:value("kp.dat", translate(string.format("视频规则: <font color=\"green\">%s</font>", u)))
e:value("user.txt", translate(string.format("自定义规则: <font color=\"green\">%s条</font>", h)))

e = t:taboption("base", ListValue, "koolproxy_port", translate("端口控制"))
e.default = 0
e.rmempty = false
e:value(0, translate("关闭"))
e:value(1, translate("开启"))

e = t:taboption("base", Value, "koolproxy_bp_port", translate("例外端口"))
e:depends("koolproxy_port", "1")
e.rmempty = false
e.description = translate(string.format("<font color=\"red\"><strong>单端口:80&nbsp;&nbsp;多端口:80,443</strong></font>"))

e=t:taboption("base", Flag, "koolproxy_host", translate("开启 Adblock"))
e.default=0
e:depends("koolproxy_mode", "2")
e.description = translate(string.format("<font color=\"green\">Adblock Plus Host: %s条</font>", i))

e = t:taboption("base", ListValue, "koolproxy_acl_default", translate("默认访问控制"))
e.default = 1
e.rmempty = false
e:value(0, translate("不过滤"))
e:value(1, translate("仅 HTTP"))
e:value(2, translate("HTTP 和 HTTPS"))
e:value(3, translate("所有端口"))
e.description = translate(string.format("<font color=\"blue\"><strong>访问控制设置中其他主机的默认规则</strong></font>"))

t:tab("white_weblist",translate("网站白名单设置"))

local i = "/etc/adblocklist/adbypass"
e = t:taboption("white_weblist", TextValue, "adbypass_domain")
e.description = translate("加入的网址将不会被过滤，只能输入 WEB 地址，每个行一个地址，如：google.com。")
e.rows = 28
e.wrap = "off"
e.rmempty = false

function e.cfgvalue()
	return fs.readfile(i) or ""
end

function e.write(self, section, value)
	if value then
		value = value:gsub("\r\n", "\n")
	else
		value = ""
	end
	fs.writefile("/tmp/adbypass", value)
	if (luci.sys.call("cmp -s /tmp/adbypass /etc/adblocklist/adbypass") == 1) then
		fs.writefile(i, value)
	end
	fs.remove("/tmp/adbypass")
end

t:tab("weblist",translate("网站黑名单设置"))

local i = "/etc/adblocklist/adblock"
e = t:taboption("weblist", TextValue, "adblock_domain")
e.description = translate("加入的网址将被过滤，只能输入 WEB 地址，每个行一个地址，如：google.com。")
e.rows = 28
e.wrap = "off"
e.rmempty = false

function e.cfgvalue()
	return fs.readfile(i) or ""
end

function e.write(self, section, value)
	if value then
		value = value:gsub("\r\n", "\n")
	else
		value = ""
	end
	fs.writefile("/tmp/adblock", value)
	if (luci.sys.call("cmp -s /tmp/adblock /etc/adblocklist/adblock") == 1) then
		fs.writefile(i, value)
	end
	fs.remove("/tmp/adblock")
end

t:tab("white_iplist",translate("IP白名单设置"))

local i = "/etc/adblocklist/adbypassip"
e = t:taboption("white_iplist", TextValue, "adbypass_ip")
e.description = translate("将入的地址将不会被过滤，请输入 IP 地址或地址段，每个行一个记录，如：112.123.134.145/24 或 112.123.134.145。")
e.rows = 28
e.wrap = "off"
e.rmempty = false

function e.cfgvalue()
	return fs.readfile(i) or ""
end

function e.write(self, section, value)
	if value then
		value = value:gsub("\r\n", "\n")
	else
		value = ""
	end
	fs.writefile("/tmp/adbypassip", value)
	if (luci.sys.call("cmp -s /tmp/adbypassip /etc/adblocklist/adbypassip") == 1) then
		fs.writefile(i, value)
	end
	fs.remove("/tmp/adbypassip")
end

t:tab("iplist",translate("IP 黑名单设置"))

local i = "/etc/adblocklist/adblockip"
e = t:taboption("iplist", TextValue, "adblock_ip")
e.description = translate("加入的地址将使用代理，请输入 IP 地址或地址段，每个行一个记录，如：112.123.134.145/24 或 112.123.134.145。")
e.rows = 28
e.wrap = "off"
e.rmempty = false

function e.cfgvalue()
	return fs.readfile(i) or ""
end

function e.write(self, section, value)
	if value then
		value = value:gsub("\r\n", "\n")
	else
		value = ""
	end
	fs.writefile("/tmp/adblockip", value)
	if (luci.sys.call("cmp -s /tmp/adblockip /etc/adblocklist/adblockip") == 1) then
		fs.writefile(i, value)
	end
	fs.remove("/tmp/adblockip")
end

t:tab("customlist", translate("自定义规则"))

local i = "/usr/share/koolproxy/data/user.txt"
e = t:taboption("customlist", TextValue, "user_rule")
e.description = translate("输入你的自定义规则，每条规则一行。")
e.rows = 28
e.wrap = "off"
e.rmempty = false

function e.cfgvalue()
	return fs.readfile(i) or ""
end

function e.write(self, section, value)
	if value then
		value = value:gsub("\r\n", "\n")
	else
		value = ""
	end
	fs.writefile("/tmp/user.txt", value)
	if (luci.sys.call("cmp -s /tmp/user.txt /usr/share/koolproxy/data/user.txt") == 1) then
		fs.writefile(i, value)
	end
	fs.remove("/tmp/user.txt")
end

t=o:section(TypedSection,"acl_rule",translate("访问控制"),
translate("访问控制列表是用于指定特殊 IP 过滤模式的工具，如为已安装证书的客户端开启 HTTPS 广告过滤等，MAC 或者 IP 必须填写其中一项。"))
t.template="cbi/tblsection"
t.sortable=true
t.anonymous=true
t.addremove=true
e=t:option(Value,"remarks",translate("客户端备注"))
e.width="30%"
e.rmempty=true
e=t:option(Value,"ipaddr",translate("IP 地址"))
e.width="20%"
e.datatype="ip4addr"
for _, entry in ipairs(arptable) do
	e:value(entry["IP address"], "%s (%s)" %{entry["IP address"], entry["HW address"]:lower()})
end
e=t:option(Value,"mac",translate("MAC 地址"))
e.width="20%"
e.rmempty=true
for _, entry in ipairs(arptable) do
	e:value(entry["HW address"]:lower(), "%s (%s)" %{entry["HW address"]:lower(), entry["IP address"]})
end
e=t:option(ListValue,"proxy_mode",translate("访问控制"))
e.width="20%"
e.default=1
e.rmempty=false
e:value(0,translate("不过滤"))
e:value(1,translate("仅 HTTP"))
e:value(2,translate("HTTP 和 HTTPS"))
e:value(3,translate("所有端口"))

return o
