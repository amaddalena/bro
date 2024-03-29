# Reverse SSH Interactive Shell Detection
# © 2015 John B. Althouse III and Jeff Atkinson
# Idea from W.
# DBDB.
#
# Detects when multiple characters have been typed into a reverse SSH shell and returned.
# Linux to Linux version 1.0

redef enum Notice::Type += {
  SSH_Reverse_Shell,
};

global lssh_conns:table[string] of count &redef;
global linux_echo:table[string] of count &redef;

event ssh_server_version(c: connection, version: string)
{
  if ( c$uid !in lssh_conns ) 
  {
	lssh_conns[c$uid] = 0;
	linux_echo[c$uid] = 0;
  }
  if ( c$uid !in linux_echo )
  {
    linux_echo[c$uid] = 0;
  }
}

event new_packet(c: connection, p: pkt_hdr)
{ 
if ( ! c?$service ) { return; }
if ( /SSH/ !in cat(c$service) ) { return; }

local is_src:bool &default=F;
if ( p$ip$src == c$id$orig_h ) { is_src = T; }
if ( p$ip$src != c$id$orig_h ) { is_src = F; }

if ( is_src == F && p$tcp$dl == 96 && lssh_conns[c$uid] == 0 )
  {
        lssh_conns[c$uid] += 1;
        return;
  }

if ( is_src == T && p$tcp$dl == 96 && lssh_conns[c$uid] == 1 )
{
  	lssh_conns[c$uid] += 1;
	return;
}

if ( is_src == F && p$tcp$dl == 0 && lssh_conns[c$uid] == 2 ) 
{
	lssh_conns[c$uid] += 1;
	return;
}
if ( is_src == F && p$tcp$dl == 96 && lssh_conns[c$uid] >= 3 )
  {
        lssh_conns[c$uid] += 1;
	return;
  }
if ( is_src == T && p$tcp$dl == 96 && lssh_conns[c$uid] >= 4 )
{
	lssh_conns[c$uid] += 1;
	return;
}
if ( is_src == F && p$tcp$dl == 0 && lssh_conns[c$uid] >= 5 ) 
{
	lssh_conns[c$uid] += 1;
	return;
}

if ( is_src == T && p$tcp$dl > 96 && lssh_conns[c$uid] >= 10 )
{
	lssh_conns[c$uid] += 1;
	linux_echo[c$uid] = 1;
}

else { lssh_conns[c$uid] = 0; return; }

if ( c$uid in linux_echo ) 
  {
    if ( linux_echo[c$uid] == 1 ) 
    {
      NOTICE([$note=SSH_Reverse_Shell,
	    $conn = c,
	    $msg = fmt("Active SSH Reverse Shell from Linux: %s to Linux: %s:%s", c$id$orig_h,c$id$resp_h,c$id$resp_p),
	    $sub = "Consecutive characters typed into a reverse SSH shell followed by a return."
	  ]);
     linux_echo[c$uid] = 0;
     lssh_conns[c$uid] = 0;
    }
  }
}
