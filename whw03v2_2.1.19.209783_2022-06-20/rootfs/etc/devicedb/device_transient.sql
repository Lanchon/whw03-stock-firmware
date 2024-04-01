PRAGMA foreign_keys=ON;
BEGIN TRANSACTION;
CREATE TABLE t_revision(
    lastChangedRevision  INTEGER NOT NULL,
    backupNeeded         BOOLEAN NOT NULL CHECK((backupNeeded > -1) AND (backupNeeded < 2)));
CREATE TABLE t_device(
    lastChangedRevision  INTEGER NOT NULL,
    deviceNo             INTEGER NOT NULL);
CREATE TABLE t_interface(
    guestNet             BOOLEAN CHECK((guestNet > -1) AND (guestNet < 2)),
    connectionOnline     BOOLEAN CHECK((connectionOnline > -1) AND (connectionOnline < 2)),
    detectedByDriver     BOOLEAN CHECK((detectedByDriver > -1) AND (detectedByDriver < 2)),
    mu_mimo              BOOLEAN CHECK((mu_mimo > -1) AND (mu_mimo < 2)),
    wifiBand             TEXT,
    connectionType       TEXT,
    ethernetPort         INTEGER,
    parentDeviceId       TEXT,
    ap_bssid             TEXT COLLATE NOCASE,
    ap_intf              TEXT,
    remote               BOOLEAN CHECK((remote > -1) AND (remote < 2)),
    l2hw                 INTEGER CHECK((l2hw > -1) AND (l2hw < 3)),
    interfaceNo          INTEGER NOT NULL);
CREATE TABLE t_ipaddr(
    ip                   TEXT NOT NULL COLLATE NOCASE,
    type                 TEXT NOT NULL,
    interfaceNo          INTEGER NOT NULL);
CREATE TABLE t_ethernet_ports(
    port                 INTEGER UNIQUE NOT NULL,
    linkUp               BOOLEAN CHECK((linkup > -1) AND (linkup < 2)),
    linkSpeed            TEXT);
CREATE TABLE t_ethernet_macs(
    macAddr              TEXT NOT NULL COLLATE NOCASE,
    port                 INTEGER NOT NULL,
    linkSpeed            TEXT NOT NULL,
    parentDeviceId       TEXT NOT NULL,
    remote               BOOLEAN NOT NULL CHECK((remote > -1) AND (remote < 2)));
CREATE TABLE t_wifi_macs(
    macAddr              TEXT NOT NULL COLLATE NOCASE,
    guestNet             BOOLEAN CHECK((guestNet > -1) AND (guestNet < 2)),
    mu_mimo              BOOLEAN CHECK((mu_mimo > -1) AND (mu_mimo < 2)),
    wifiBand             TEXT,
    connectionType       TEXT,
    parentDeviceId       TEXT,
    ap_bssid             TEXT COLLATE NOCASE,
    ap_intf              TEXT,
    remote               BOOLEAN NOT NULL CHECK((remote > -1) AND (remote < 2)));
CREATE TABLE t_arp_macs(
    ip                   TEXT NOT NULL,
    type                 TEXT NOT NULL,
    state                INTEGER NOT NULL CHECK((state > -1) AND (state < 3)),
    intf                 TEXT NOT NULL,
    probeState           INTEGER CHECK((probeState > -1) AND (probeState < 4)),
    macAddr              TEXT NOT NULL COLLATE NOCASE);
CREATE TABLE t_infra_macs(
    ip                   TEXT NOT NULL,
    type                 TEXT NOT NULL,
    connectionOnline     BOOLEAN CHECK((connectionOnline > -1) AND (connectionOnline < 2)),
    macAddr              TEXT NOT NULL COLLATE NOCASE);
CREATE TABLE t_ipclient_macs(
    ip                   TEXT NOT NULL,
    type                 TEXT NOT NULL,
    lastSeenOnline       INTEGER NOT NULL,
    macAddr              TEXT NOT NULL COLLATE NOCASE);
CREATE TABLE t_deleted(
    deviceId             TEXT UNIQUE NOT NULL,
    lastChangedRevision  INTEGER NOT NULL);
COMMIT; 
