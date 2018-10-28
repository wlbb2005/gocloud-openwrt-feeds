-- Copyright (C) 2017 yushi studio <ywb94@qq.com>
-- Licensed to the public under the GNU General Public License v3.

local m, s, o
local shadowsocksr = "shadowsocksr"
local uci = luci.model.uci.cursor()
local ipkg = require("luci.model.ipkg")

local tabname = {translate("Client"), translate("Server"), translate("Status")};
local tabmenu = {
    luci.dispatcher.build_nodeurl("admin", "network", "shadowsocksr"),
    luci.dispatcher.build_nodeurl("admin", "network", "shadowsocksr", "server"),
    luci.dispatcher.build_nodeurl("admin", "network", "shadowsocksr", "status"),
};
local isact = {false, true, false};
local tabcount = #tabname;

m = Map(shadowsocksr, translate(""))
m.description = translate("ShadowsocksR Server")
m.istabform = true
m.tabcount = tabcount
m.tabname = tabname;
m.tabmenu = tabmenu;
m.isact = isact;

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
}

obfs = {
    "plain",
    "http_simple",
    "http_post",
    "tls1.2_ticket_auth",
}

-- [[ Global Setting ]]--
s = m:section(TypedSection, "server_global", translate("Global Setting"))
s.anonymous = true

o = s:option(Flag, "enable_server", translate("Enable"))
o.rmempty = false

-- [[ Server Setting ]]--
s = m:section(TypedSection, "server_config", translate("Server Setting"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = luci.dispatcher.build_url("admin/network/shadowsocksr/server/%s")
function s.create(self, name)
    local sid = TypedSection.create(self, name)
    if sid then
        luci.http.redirect(self.extedit % sid)
        return
    end
end

o = s:option(Flag, "enable", translate("Enable"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or translate("0")
end
o.rmempty = false

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
    local v = Value.cfgvalue(...)
    return v and v:upper() or "?"
end

o = s:option(DummyValue, "protocol", translate("Protocol"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

o = s:option(DummyValue, "obfs", translate("Obfs"))
function o.cfgvalue(...)
    return Value.cfgvalue(...) or "?"
end

return m
