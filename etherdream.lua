--[[ 

MIT License

Copyright (c) 2019 Andrew Berry

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

etherdream_proto = Proto("etherdream","Ether-Dream Laser Protocol")

-- UDP and TCP Dissector Tables
udp_table = DissectorTable.get("udp.port")

-- Globals
dissector_version = "0.1.0"
dissector_date = "2019-07-18"

local BCAST_PORT = 7654
local STREAM_PORT = 7765

etherdream_cmdText = {
  [0x70]= "Prepare Stream"    ,
  [0x62]= "Begin Playback"    ,
  [0x64]= "Write Data"        ,
  [0x44]= "Write Data"        ,
  [0x71]= "Queue Rate Change" ,
  [0x73]= "Stop"              ,
  [0x76]= "Version Request"   ,
  [0x3f]=  "Ping"             ,
  [0x00]=  "E-Stop"           ,
  [0xff]=  "E-Stop"           ,
  [0x49]= "Install Plugin"	  ,
  [0x50]= "Pass Plugin Data"  ,
}

etherdream_responseText = {
  [0x61]= "ACK"    ,
  [0x46]= "NAK[Full]"    ,
  [0x49]= "NAK[Invalid]" ,
  [0x21]= "NAK[Stop]"          ,
}

etherdream_lightEngineStateText = {
  [0x00]= "Ready",
  [0x01]= "Warmup",
  [0x02]= "Cooldown",
  [0x03]= "Emergency Stop",
  [0x04]= "UNDEFINED",
}

etherdream_playbackStateText = { 
  [0x00]= "Idle",
  [0x01]= "Prepared",
  [0x02]= "Playing",
  [0x03]= "UNDEFINED",
}

etherdream_sourceText = { 
  [0x00]= "Network",
  [0x01]= "SD Card",
  [0x02]= "Internal Abstract",
  [0x03]= "UNDEFINED",
}
 
local hwRev_field                  = ProtoField.uint16( "etherdream.broadcast.hw_version",          "HW Version",                    base.DEC)
local swRev_field                  = ProtoField.uint16( "etherdream.broadcast.sw_version",          "SW Version",                    base.DEC)
local bufferCapacity_field         = ProtoField.uint16( "etherdream.broadcast.buffer_cap",          "Buffer Capacity",               base.DEC)
local maxPointRate_field           = ProtoField.uint16( "etherdream.broadcast.max_point_rate",      "Max Point Rate",                base.DEC)
                                                                                                                                     
local dac_protocol_field           = ProtoField.uint8(  "etherdream.dac_status.protocol",           "DAC Protocol",                  base.DEC)
local dac_le_state_field           = ProtoField.uint8(  "etherdream.dac_status.le_state",           "DAC Light Engine State",        base.HEX, etherdream_lightEngineStateText)
local dac_playbackstate_field      = ProtoField.uint8(  "etherdream.dac_status.playback_sate",      "DAC Playback State",            base.HEX, etherdream_playbackStateText)
local dac_source_field             = ProtoField.uint8(  "etherdream.dac_status.source",             "DAC Source",                    base.HEX, etherdream_sourceText)
                                                                                                                                     
local dac_le_flags_field           = ProtoField.uint16( "etherdream.dac_status.le.estop_network",   "Light Engine Flags",            base.HEX)
local dac_le_flags_estop_remote    = ProtoField.uint16( "etherdream.dac_status.le.estop_network",   "E-Stop due to packet or invalid command", base.DEC, NULL, 0x01)
local dac_le_flags_estop_local     = ProtoField.uint16( "etherdream.dac_status.le.estop_local",     "E-Stop due to local input",     base.DEC, NULL, 0x02)
local dac_le_flags_estop_active    = ProtoField.uint16( "etherdream.dac_status.le.estop_active",    "E-Stop is currently active",    base.DEC, NULL, 0x04)
local dac_le_flags_estop_temp      = ProtoField.uint16( "etherdream.dac_status.le.estop_temp",      "E-Stop due to overtemperature", base.DEC, NULL, 0x08)
local dac_le_flags_overtemp_active = ProtoField.uint16( "etherdream.dac_status.le.overtemp",        "Currently over temperature",    base.DEC, NULL, 0x10)
local dac_le_flags_estop_link      = ProtoField.uint16( "etherdream.dac_status.le.estop_link",      "E-Stop due to link loss",       base.DEC, NULL, 0x20)

local dac_playback_flags_field     = ProtoField.uint16( "etherdream.dac_status.playback_flags",     "DAC Playback Flags",            base.HEX)
local dac_playback_flags_shutter   = ProtoField.uint16( "etherdream.dac_status.playback.shutter",   "Shutter open",                  base.DEC, NULL, 0x01)
local dac_playback_flags_underflow = ProtoField.uint16( "etherdream.dac_status.playback.underflow", "Stream Underflow",              base.DEC, NULL, 0x02)
local dac_playback_flags_estop     = ProtoField.uint16( "etherdream.dac_status.playback.estop",     "Stream was E-Stopped",          base.DEC, NULL, 0x04)


local dac_source_flags_field       = ProtoField.uint16( "etherdream.dac_status.source_flags",       "DAC Source Flags",     base.DEC)
local dac_buffer_fullness_field    = ProtoField.uint16( "etherdream.dac_status.buffer_fullness",    "DAC Buffer Fullness",  base.DEC)
local dac_pointrate_field          = ProtoField.uint32( "etherdream.dac_status.pointrate", 	        "DAC Pointrate",        base.DEC)
local dac_pointcount_field         = ProtoField.uint32( "etherdream.dac_status.pointcount", 	       "DAC Point Count",   base.DEC)
local dac_versionString_field      = ProtoField.string( "etherdream.dac_status.version_string",     "DAC Version String",   base.ASCII)
                                                                                                                            
local command_field				   = ProtoField.uint8(  "etherdream.command",                       "Command",              base.HEX, etherdream_cmdText)
local response_field		       = ProtoField.none(    "etherdream.response",						"Response",       		base.ASCII)
local responsecode_field   		   = ProtoField.uint8(  "etherdream.response.code",                 "DAC Response",         base.HEX, etherdream_responseText)
local responsecommand_field		   = ProtoField.uint8(  "etherdream.response.command",              "Command",              base.HEX, etherdream_cmdText)
                                   
local data_nPoints				   = ProtoField.uint16( "etherdream.data.npoints", "Num Points", base.DEC)

local ef_excess_data			   = ProtoExpert.new("etherdream.expert.excessdata", "Field missing or malformed", expert.group.MALFORMED, expert.severity.WARN)

etherdream_proto.fields = {
    hwRev_field,
	swRev_field,
	bufferCapacity_field,
	maxPointRate_field,
	
	dac_protocol_field,
	dac_le_state_field,      
	dac_playbackstate_field  ,
	dac_source_field         ,
	
	dac_le_flags_field       ,
	dac_le_flags_estop_remote   ,
	dac_le_flags_estop_local     ,
	dac_le_flags_estop_active    ,
	dac_le_flags_estop_temp      ,
	dac_le_flags_overtemp_active ,
	dac_le_flags_estop_link      ,
	
	dac_playback_flags_field ,
	dac_playback_flags_shutter   ,
	dac_playback_flags_underflow ,
	dac_playback_flags_estop     ,
	
	dac_source_flags_field   ,
	dac_buffer_fullness_field,
	dac_pointrate_field      ,
	dac_pointcount_field     ,

	dac_versionString_field,

	command_field,
	response_field,
	responsecode_field,
	responsecommand_field,
	
	data_nPoints,
}

etherdream_proto.experts = {
	ef_excess_data
}

function dissect_leflags(buffer, pinfo, tree)
	local subtree = tree:add_le(dac_le_flags_field, buffer(0,2))
	subtree:add_le(dac_le_flags_estop_remote, buffer(0,2))
	subtree:add_le(dac_le_flags_estop_local, buffer(0,2))
	subtree:add_le(dac_le_flags_estop_active, buffer(0,2))
	subtree:add_le(dac_le_flags_estop_temp, buffer(0,2))
	subtree:add_le(dac_le_flags_overtemp_active, buffer(0,2))
	subtree:add_le(dac_le_flags_estop_link, buffer(0,2))
end

function dissect_playback_flags(buffer, pinfo, tree)
	local subtree = tree:add_le(dac_playback_flags_field, buffer(0,2))
	subtree:add_le(dac_playback_flags_shutter, buffer(0,2))
	subtree:add_le(dac_playback_flags_underflow, buffer(0,2))
	subtree:add_le(dac_playback_flags_estop, buffer(0,2))
end

function dissect_dacstatus(buffer, pinfo, tree)
	if(buffer:len() > 22) then 
		ef = tree:add_proto_expert_info(ef_excess_data, string.format("Excess data appended to status (expected 20 bytes, got %d)", buffer:len()-2))
	end
    subtree = tree:add(buffer(2,22),"DAC Status")

	subtree:add_le(dac_protocol_field, buffer(0,1))
	subtree:add_le(dac_le_state_field, buffer(1,1))
	subtree:add_le(dac_playbackstate_field, buffer(2,1))
	subtree:add_le(dac_source_field, buffer(3,1))
	dissect_leflags(buffer(4,2), pinfo, subtree)
	dissect_playback_flags(buffer(6,2), pinfo, subtree)
	subtree:add_le(dac_source_flags_field, buffer(8,2))
	subtree:add_le(dac_buffer_fullness_field, buffer(10,2))
	subtree:add_le(dac_pointrate_field, buffer(12,4))
	subtree:add_le(dac_pointcount_field, buffer(16,4))
end

function dissect_data(buffer, pinfo, tree)
	subtree = tree
	subtree:add_le(data_nPoints, buffer(1,2))
end

function command_infostring(buffer)
	local cmdtext = etherdream_cmdText[buffer(0,1):uint()] or string.format("Unknown command: 0x%02x", buffer(0,1):uint())
	return " ("..cmdtext..")"
end

function response_infostring(buffer)
	local resp = etherdream_responseText[buffer(0,1):uint()] or "Unknown response"
	local respcmd = etherdream_cmdText[buffer(1,1):uint()] or "Unknown command"
	return " ("..resp..":"..respcmd..")"
end

function etherdream_proto.dissector(buffer,pinfo,tree)
	pinfo.cols.protocol = "EtherDream"
	
	if(pinfo.dst_port == BCAST_PORT) then
		pinfo.cols.info = "DAC Advertisement"
		local subtree = tree:add(etherdream_proto, buffer(), "EtherDream [DAC Advertisement]")
		--TODO: Report MAC Address
		subtree:add_le(hwRev_field, buffer(6,2) )
		subtree:add_le(swRev_field, buffer(8,2) )
		subtree:add_le(bufferCapacity_field, buffer(10,2) )
		subtree:add_le(maxPointRate_field, buffer(12,4) )
		dissect_dacstatus(buffer(16, buffer:len()-16), pinfo, subtree)
	
	elseif(pinfo.dst_port == STREAM_PORT) then
		pinfo.cols.info = "Control Data"
		local subtree = tree:add(etherdream_proto, buffer(), "EtherDream [Control]")
		
		local command = buffer(0,1):string()
		
		subtree:add(command_field, buffer(0,1))

		subtree:append_text(command_infostring(buffer))
		pinfo.cols.info:append(command_infostring(buffer))

	elseif(pinfo.src_port == STREAM_PORT) then
		pinfo.cols.info = "DAC Response"
		local subtree = tree:add(etherdream_proto, buffer(), "EtherDream [DAC Response]")
		
		local dissect_status = true
		
		local dac_response = buffer(0,1):string()
		subtree = subtree:add(response_field, buffer())

		subtree:add(responsecode_field, buffer(0,1))
		subtree:add(responsecommand_field, buffer(1,1))
		
		if(dac_response == 'v') then
			subtree:append_text(   " (Version Report)")
			pinfo.cols.info:append(" (Version Report)")
			subtree:add(dac_versionString_field, buffer(1,31) )
		else 
			pinfo.cols.info:append(response_infostring(buffer))
			dissect_dacstatus(buffer(), pinfo, subtree)
		end
	end
end -- end function citp_proto.dissector

udp_table = DissectorTable.get("udp.port")
tcp_table = DissectorTable.get("tcp.port")

udp_table:add(BCAST_PORT, etherdream_proto)
tcp_table:add(STREAM_PORT, etherdream_proto)
