PRAGMA foreign_keys = ON;

/*
Database info
   versionMajor - database version, should be hardcoded
   versionMinor - database version, should be hardcoded
   backupNeeded - if deferred backup is needed
*/
CREATE TABLE dbinfo(
    versionMajor         INTEGER NOT NULL,
    versionMinor         INTEGER NOT NULL,
    backupNeeded         INTEGER NOT NULL);

/* Version of this schema, 0.2 */
INSERT INTO "dbinfo" VALUES(0,2,0);

/*
For HomeKit client profile data
Keeps the client profile information given to us by HomeKit
    profNo - client profile number/client identifier
    lanId - LAN ID
    credType - mac/wpapsk/wpapass
    credMac - MAC address
    credWpaPsk - 32 byte WPA-PSK in hex
    credWpaPass - passphrase
    wanFirewallType - fullaccess/allowlist
    lanFirewallType - fullaccess/allowlist
    violationResetTime - UNIX Epoch time when access violation is reset
    violationTime - UNIX Epoch time of most recent access violation
    violationReset - 0/1 if access violation was reset
    violationFound - 0/1 if there is an access violation
*/
CREATE TABLE ClientProfiles(
    profNo               INTEGER PRIMARY KEY,
    lanId                INTEGER NOT NULL,
    credType             TEXT NOT NULL,
    credMac              TEXT COLLATE NOCASE,
    credWpaPsk           TEXT COLLATE NOCASE,
    credWpaPass          TEXT,
    wanFirewallType      TEXT,
    lanFirewallType      TEXT,
    violationResetTime   TEXT,
    violationTime        TEXT,
    violationReset       INTEGER,
    violationFound       INTEGER);

/*
Homekit firewall rules set via PAL
    ruleNo - internal database rule ID
    type - "port" or "icmp"
    serverHost - domain name/IP address
    serverHostType - if serverHost is "hostname", "ipv4", or "ipv6"
    transportProtocol - TCP/UDP
    portRange - range of port
    icmpV4Types - ICMP type list for IPv4
    icmpV6Types - ICMP type list for IPv6
    profNo - client profile number
*/
CREATE TABLE WANFirewallRule(
    ruleNo               INTEGER PRIMARY KEY,
    type                 TEXT NOT NULL,
    serverHost           TEXT NOT NULL,
    serverHostType       TEXT NOT NULL,
    transportProtocol    TEXT,
    portRange            TEXT,
    icmpV4Types          TEXT,
    icmpV6Types          TEXT,
    profNo               INTEGER NOT NULL REFERENCES ClientProfiles(profNo) ON DELETE CASCADE);

/*
Homekit firewall rules for LAN
    lanRuleNo - internal database rule ID
    type - "static", "dynamic", "multicastbriding", "staticIcmp"
    direction - in/out
    transportProtocol - TCP/UDP
    remoteLanIdList - remote LAN idenfitiers
    numRemoteLanId - number of identifiers in the list
    ipAddr - IP address
    ipType - ipv4/ipv6
    ipValid - if IP address is valid
    portRange - range of port
    serviceTypeProto - destination service type advertisement protocol
    DNSSD_serviceType - service type for DNS-SD (bonjour)
    SSDP_serviceTypeURI - service type URI for SSDP (UPnP)
    advertOnly - if true, discovery/advertising is allowed
    icmpV4Types - ICMP type list for IPv4
    icmpV6Types - ICMP type list for IPv6
    port - destination port
*/
CREATE TABLE LANFirewallRule(
    lanRuleNo            INTEGER PRIMARY KEY,
    type                 TEXT,
    direction            TEXT,
    transportProtocol    TEXT,
    ipAddr               TEXT COLLATE NOCASE,
    ipType               TEXT,
    ipValid              INTEGER,
    portRange            TEXT,
    serviceTypeProto     TEXT,
    DNSSD_serviceType    TEXT,
    SSDP_serviceTypeURI  TEXT,
    advertOnly           INTEGER,
    port                 INTEGER,
    icmpV4Types          TEXT,
    icmpV6Types          TEXT,
    profNo               INTEGER NOT NULL REFERENCES ClientProfiles(profNo) ON DELETE CASCADE);

/*
Remote LAN ID for LAN Firewall Rules
    remoteLanId - the LAN ID
    lanRuleNo - the LAN rule this ID is associated with
*/
CREATE TABLE RemoteLANId(
    remoteLanId          INTEGER NOT NULL,
    lanRuleNo            INTEGER NOT NULL REFERENCES LANFirewallRule(lanRuleNo) ON DELETE CASCADE);

/*
MAC to ID association, this is to make sure the MAC ID within the system is
locked to the MAC address across reboot
    macId - MAC identifier
    mac - MAC address
*/
CREATE TABLE MacId(
    macId                INTEGER PRIMARY KEY,
    mac                  TEXT COLLATE NOCASE NOT NULL);

/*
TRANSIENT TABLE
MAC to IP assocation table. This table keeps track of known MAC to IP
associations.
    macId - MAC identifier
    ipAddr       - the IP address
    ipType       - ipv4/ipv6 
*/
CREATE TABLE MacIpMapping(
    macId                INTEGER NOT NULL REFERENCES MacId(macId) ON DELETE CASCADE,
    ipAddr               TEXT COLLATE NOCASE NOT NULL,
    ipType               TEXT NOT NULL);

/*
TRANSIENT TABLE
MAC to PSK association table. This is caluclated by cross referencing AuthData
and ClientProfiles. Firewall modules key off of this table to determine which
firewall rules need to be applied.
    macId - MAC address
    profNo - client profile number
*/
CREATE TABLE AuthList(
    macId                INTEGER NOT NULL REFERENCES MacId(macId) ON DELETE CASCADE,
    profNo               INTEGER NOT NULL REFERENCES ClientProfiles(profNo) ON DELETE CASCADE);

/*
TRANSIENT TABLE
Keeps stores the MAC/PSK authentication data from hostapd, this is populated
by the hostapd each time a device is authenticated.
    macId - MAC address
    wpaPsk - WPA-PSK used to authenticate
*/
CREATE TABLE AuthData(
    macId                INTEGER NOT NULL REFERENCES MacId(macId) ON DELETE CASCADE,
    wpaPsk               TEXT COLLATE NOCASE NOT NULL);

/*
TRANSIENT TABLE
Contains the Whitelist information for DNS whitelist
    listNo - internal database whitelist ID
    macId - the MAC ID
    srcIp - the source IP address
    srcIpType - ipv4/ipv6
    serverIp - The server IP address (resolved from domain name)
    serverIpType - ipv/ipv6
    ruleNo - references which firewall rule is being applied
*/
CREATE TABLE DNSWhitelist(
    listNo               INTEGER PRIMARY KEY,
    macId                INTEGER NOT NULL REFERENCES MacId(macId),
    srcIp                TEXT COLLATE NOCASE,
    srcIpType            TEXT,
    serverIp             TEXT COLLATE NOCASE,
    serverIpType         TEXT,
    ruleNo               INTEGER NOT NULL REFERENCES WANFirewallRule(ruleNo) ON DELETE CASCADE);

/*
TRANSIENT TABLE
Data for DNSSD service
    listNo       - internal DNSSD service entry list number
    mac          - the MAC address of accessory (optional if IP is set)
    ipAddr       - the IP address (optional if mac is set)
    ipType       - ipv4/ipv6 (optional if mac is set)
    lanRuleNo    - references LANFirewallRule.lanRuleNo
    port         - port number
    ebtablesRule - optional generated ebtable rule for debug purposes
*/
CREATE TABLE DNSSDService(
    listNo               INTEGER PRIMARY KEY,
    mac                  TEXT COLLATE NOCASE,
    ipAddr               TEXT COLLATE NOCASE,
    ipType               TEXT,
    lanRuleNo            INTEGER NOT NULL REFERENCES LANFirewallRule(lanRuleNo) ON DELETE CASCADE,
    port                 INTEGER NOT NULL,
    ebtablesRule         TEXT COLLATE NOCASE);

/*
TRANSIENT TABLE
Data for SSDP service
    listNo       - internal SSDP entry list number
    mac          - the MAC address of accessory (optional if IP is set)
    ipAddr       - the IP address (optional if mac is set)
    ipType       - ipv4/ipv6 (optional if mac is set)
    lanRuleNo    - references LANFirewallRule.lanRuleNo
    type         - "client" or "server"
    port         - port number
    ebtablesRule - optional generated ebtable rule for debug purposes
*/
CREATE TABLE SSDPService(
    listNo               INTEGER PRIMARY KEY,
    mac                  TEXT COLLATE NOCASE,
    ipAddr               TEXT COLLATE NOCASE,
    ipType               TEXT,
    lanRuleNo            INTEGER NOT NULL REFERENCES LANFirewallRule(lanRuleNo) ON DELETE CASCADE,
    type                 TEXT,
    port                 INTEGER NOT NULL,
    ebtablesRule         TEXT COLLATE NOCASE);

/*
TRANSIENT TABLE
Firewall action table, for passing operations to the firewall on slave nodes
    fwaId     - firwall action identifier
    operations- The batched firewall operations
*/
CREATE TABLE FWActions(
    fwaId                INTEGER PRIMARY KEY,
    operations           TEXT NOT NULL);

/*
TRANSIENT TABLE
Firewall action table, last ID processed per device
    devId - device UUID of the master/slave node
    fwaId - the most recent ID that was returned via a get
*/
CREATE TABLE FWActionsProcessedId(
    devId                TEXT NOT NULL,
    fwaId                INTEGER NOT NULL);

