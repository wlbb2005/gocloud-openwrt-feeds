-- Copyright (C) 2017 yushi studio <ywb94@qq.com> github.com/ywb94
-- Copyright (C) 2018 lean <coolsnowwolf@gmail.com> github.com/coolsnowwolf
-- Licensed to the public under the GNU General Public License v3.

local m, s, o, kcp_enable
local uci = luci.model.uci.cursor()
local ipkg = require("luci.model.ipkg")

local sys = require "luci.sys"

local function has_bin(name)
    return luci.sys.call("command -v %s >/dev/null" %{name}) == 0
end

local function has_udp_relay()
    return luci.sys.call("lsmod | grep -q TPROXY && command -v ip >/dev/null") == 0
end

local tabname = {translate("Client"), translate("Status")};
local tabmenu = {
    luci.dispatcher.build_nodeurl("admin", "network", "shadowsocksr"),
    luci.dispatcher.build_nodeurl("admin", "network", "shadowsocksr", "status"),
};
local isact = {true, false};
if has_bin("ssr-server") then
    table.insert(tabname, 2, translate("Server"))
    table.insert(tabmenu, 2, luci.dispatcher.build_nodeurl("admin", "network", "shadowsocksr", "server"))
    table.insert(isact, 2, false)
end
local tabcount = #tabname;

m = Map("shadowsocksr", translate(""))
m.description = translate("ShadowsocksR Client")
m.istabform = true
m.tabcount = tabcount
m.tabname = tabname;
m.tabmenu = tabmenu;
m.isact = isact;

local server_table = {}
local server_count = 0
local encrypt_methods = {
    "none",
    "table",
    "rc4",
    "rc4-md5",
    "rc4-md5-6",
    "aes-128-cfb",
    "aes-192-cfb",
    "aes-256-cfb",
    "aes-128-ctr",
    "aes-192-ctr",
    "aes-256-ctr",
    "bf-cfb",
    "camellia-128-cfb",
    "camellia-192-cfb",
    "camellia-256-cfb",
    "cast5-cfb",
    "des-cfb",
    "idea-cfb",
    "rc2-cfb",
    "seed-cfb",
    "salsa20",
    "chacha20",
    "chacha20-ietf",
}

local protocol = {
    "origin",
    "verify_simple",
    "verify_sha1",
    "auth_sha1",
    "auth_sha1_v2",
    "auth_sha1_v4",
    "auth_aes128_sha1",
    "auth_aes128_md5",
    "auth_chain_a",
    "auth_chain_b",
    "auth_chain_c",
    "auth_chain_d",
    "auth_chain_e",
    "auth_chain_f",
}

obfs = {
    "plain",
    "http_simple",
    "http_post",
    "tls_simple",
    "tls1.2_ticket_auth",
}

uci:foreach("shadowsocksr", "servers", function(s)
    if s.alias then
        server_table[s[".name"]] = s.alias
        server_count = server_count + 1
    elseif s.server and s.server_port then
        server_table[s[".name"]] = "%s:%s" % {s.server, s.server_port}
        server_count = server_count + 1
    end
end)

-- [[ Server Setting ]]--
s = m:section(TypedSection, "servers", translate("Server Setting"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = luci.dispatcher.build_url("admin/network/shadowsocksr/client/%s")
function s.create(self, name)
    local sid = TypedSection.create(self, name)
    if sid then
        luci.http.redirect(self.extedit % sid)
        return
    end
end

o = s:option(DummyValue, "alias", translate("Alias (optional)"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or translate("None")
end

o = s:option(DummyValue, "server", translate("Server Address"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

o = s:option(DummyValue, "server_port", translate("Server Port"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

o = s:option(DummyValue, "encrypt_method", translate("Encrypt Method"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

o = s:option(DummyValue, "protocol", translate("Protocol"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

o = s:option(DummyValue, "obfs", translate("Obfs"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

if has_bin("ssr-kcptun") then
    o = s:option(DummyValue, "kcp_enable", translate("Enable KcpTun"))
    function o.cfgvalue(...)
        return Value.cfgvalue(...) == "1" and translate("Enable") or translate("Disable")
    end
end

o = s:option(DummyValue, "switch_enable", translate("Auto Switch"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) == "1" and translate("Enable") or translate("Disable")
end

o = s:option(DummyValue, "weight", translate("Weight"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "10"
end

-- [[ Global Setting ]]--
s = m:section(TypedSection, "global")
s.anonymous = true

s:tab("base", translate("Global Setting"))

o = s:taboption("base", Flag, "enable", translate("Enable"))
o.rmempty = false

o = s:taboption("base", ListValue, "global_server", translate("Server"))
if has_bin("haproxy") and server_count > 1 then
    o:value("__haproxy__", translate("Load Balancing"))
end
for k, v in pairs(server_table) do o:value(k, v) end
o.default = "nil"
o.optional = true

if has_udp_relay() then
    o = s:taboption("base", ListValue, "udp_relay_server", translate("UDP Relay Server"))
    o:value("", translate("Disable"))
    o:value("same", translate("Same as Global Server"))
    for k, v in pairs(server_table) do o:value(k, v) end
end

o = s:taboption("base", ListValue, "run_mode", translate("Operating mode"))
o:value("router", translate("IP Route Mode"))
o:value("gfw", translate("GFW List Mode"))
o.rmempty = false

o = s:taboption("base", Flag, "tunnel_enable", translate("Enable Tunnel (DNS)"))
o:depends("run_mode", "router")
o.default = 0

o = s:taboption("base", Value, "tunnel_port", translate("Tunnel Port"))
o:depends("run_mode", "router")
o.datatype = "port"
o.default = 5300

o = s:taboption("base", DynamicList, "gfw_list", translate("Optional GFW domains"))
o:depends("run_mode", "gfw")
o.datatype = "hostname"

o = s:taboption("base", ListValue, "pdnsd_enable", translate("DNS Mode"))
o:value("0", translate("Use DNS Tunnel"))
if has_bin("pdnsd") then
    o:value("1", translate("Use pdnsd"))
end
o.rmempty = false

o = s:taboption("base", ListValue, "tunnel_forward", translate("Upstream DNS Server"))
o:value("8.8.4.4:53", translate("Google Public DNS (8.8.4.4)"))
o:value("8.8.8.8:53", translate("Google Public DNS (8.8.8.8)"))
o:value("208.67.222.222:53", translate("OpenDNS (208.67.222.222)"))
o:value("208.67.220.220:53", translate("OpenDNS (208.67.220.220)"))
o:value("209.244.0.3:53", translate("Level 3 Public DNS (209.244.0.3)"))
o:value("209.244.0.4:53", translate("Level 3 Public DNS (209.244.0.4)"))
o:value("4.2.2.1:53", translate("Level 3 Public DNS (4.2.2.1)"))
o:value("4.2.2.2:53", translate("Level 3 Public DNS (4.2.2.2)"))
o:value("4.2.2.3:53", translate("Level 3 Public DNS (4.2.2.3)"))
o:value("4.2.2.4:53", translate("Level 3 Public DNS (4.2.2.4)"))
o:value("1.1.1.1:53", translate("Cloudflare DNS (1.1.1.1)"))

s:tab("advance", translate("Advanced Setting"))

o = s:taboption("advance", Flag, "monitor_enable", translate("Enable Process Monitor"))
o.rmempty = false

o = s:taboption("advance", Flag, "enable_switch", translate("Enable Auto Switch"))
o.rmempty = false

o = s:taboption("advance", Value, "switch_time", translate("Switch check interval (second)"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 600

o = s:taboption("advance", Value, "switch_timeout", translate("Check timout (second)"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 3

-- [[ SOCKS5 Proxy ]]--
if has_bin("ssr-local") then
    o = s:taboption("advance", Flag, "enable_ssr_local", translate("Enable SOCKS5 Proxy"))
    o.rmempty = false

    o = s:taboption("advance", ListValue, "ssr_local_server", translate("[SOCKS5] SSR Server"))
    for k, v in pairs(server_table) do o:value(k, v) end
    o:depends("enable_ssr_local", "1")
    o.default = ""

    o = s:taboption("advance", Value, "ssr_local_port", translate("[SOCKS5] Listen Port"))
    o.datatype = "port"
    o:depends("enable_ssr_local", "1")
    o.default = 1080
end

if has_bin("ssr-subscribe") and has_bin("bash") then
    s:tab("subscribe", translate("Server Subscription"))

    o = s:taboption("subscribe", Flag, "subscribe_enable", translate("Auto Update"))
    o.rmempty = false
    o = s:taboption("subscribe", ListValue, "subscribe_update_time", translate("Update Time (every day)"))
    for t = 0,23 do
        o:value(t, t..":00")
    end
    o.default=2
    o.rmempty = false

    o = s:taboption("subscribe", DynamicList, "subscribe_url", translate("Subscription URL"))
    o.rmempty = true

    o = s:taboption("subscribe", Button, "update", translate("Subscription Status"))
    o.inputtitle = translate("Update Subscription")
    o.inputstyle = "reload"
    o.write = function()
        luci.sys.call("/usr/bin/ssr-subscribe >/dev/null 2>&1")
        luci.http.redirect(luci.dispatcher.build_url("admin", "network", "shadowsocksr", "client"))
    end

    o = s:taboption("subscribe", Button, "delete", translate("Server Status"))
    o.description = string.format(translate("Server Count") ..  ": %d", server_count)
    o.inputtitle = translate("Delete all severs")
    o.inputstyle = "reload"
    o.write = function()
        uci:delete_all("shadowsocksr", "servers", function(s) return true end)
        uci:save("shadowsocksr")
        luci.http.redirect(luci.dispatcher.build_url("admin", "network", "shadowsocksr", "client"))
    end
end

-- [[ Access Control ]]--
s = m:section(TypedSection, "access_control", translate("Access Control"))
s.anonymous = true

-- Part of WAN
s:tab("wan_ac", translate("Interfaces - WAN"))

o = s:taboption("wan_ac", Value, "wan_bp_list", translate("Bypassed IP List"))
o:value("/dev/null", translate("NULL - As Global Proxy"))
o.default = "/dev/null"
o.rmempty = false

o = s:taboption("wan_ac", DynamicList, "wan_bp_ips", translate("Bypassed IP"))
o.datatype = "ip4addr"

o = s:taboption("wan_ac", DynamicList, "wan_fw_ips", translate("Forwarded IP"))

-- Part of LAN
s:tab("lan_ac", translate("Interfaces - LAN"))

o = s:taboption("lan_ac", ListValue, "router_proxy", translate("Router Proxy"))
o:value("1", translatef("Normal Proxy"))
o:value("0", translatef("Bypassed Proxy"))
o:value("2", translatef("Forwarded Proxy"))
o.rmempty = false

o = s:taboption("lan_ac", ListValue, "lan_ac_mode", translate("LAN Access Control"))
o:value("0", translate("Disable"))
o:value("w", translate("Allow listed only"))
o:value("b", translate("Allow all except listed"))
o.rmempty = false

o = s:taboption("lan_ac", DynamicList, "lan_ac_ips", translate("LAN Host List"))
o.datatype = "ipaddr"

return m
