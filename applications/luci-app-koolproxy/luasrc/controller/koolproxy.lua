module("luci.controller.koolproxy",package.seeall)
function index()
	if not nixio.fs.access("/etc/config/koolproxy")then
		return
	end

	entry({"admin","network","koolproxy"},cbi("koolproxy/global"),_("KoolProxy"),35).dependent=true
end
