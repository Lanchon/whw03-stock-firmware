CREATE TABLE FirewallRules(
    ruleNo               INTEGER PRIMARY KEY,
    direction            TEXT,
    portMappingProtocol  TEXT,
    transportProtocol    TEXT,
    serverHost           TEXT NOT NULL,
    serverHostType       TEXT NOT NULL,
    portRange            TEXT,
    profNo               INTEGER NOT NULL REFERENCES ClientProfiles(profNo));
CREATE TABLE MacId(
    macId                INTEGER PRIMARY KEY,
    mac                  TEXT COLLATE NOCASE NOT NULL);
CREATE TABLE AuthList(
    macId                INTEGER NOT NULL REFERENCES MacId(macId),
    profNo               INTEGER NOT NULL REFERENCES ClientProfiles(profNo));
CREATE TABLE DNSWhitelist(
    listNo               INTEGER PRIMARY KEY,
    macId                INTEGER NOT NULL REFERENCES MacId(macId),
    srcIp                TEXT,
    srcIpType            TEXT,
    serverIp             TEXT,
    serverIpType         TEXT,
    ruleNo               INTEGER NOT NULL REFERENCES FirewallRules(ruleNo));
