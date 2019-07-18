# EtherDream-Dissector
 
A basic Wireshark dissector for the Ether Dream Laser DAC Protocol

Current no packet reassembly is done, so 'write data' commands with data spanning more than one packet are not interpreted as a single command.  Doing so is probably not worthwhile.  As a result it is not always possible to identify malformed packets except by manual inspection.

See the Wireshark documentation for installation of LUA plugins: https://www.wireshark.org/docs/wsug_html_chunked/ChPluginFolders.html
