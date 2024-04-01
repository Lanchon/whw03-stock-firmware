PRAGMA foreign_keys=ON;
BEGIN TRANSACTION;
CREATE TABLE db_info(
    schemaVersion        INTEGER NOT NULL,
    transientFile        TEXT);
INSERT INTO "db_info" VALUES('3', NULL);
CREATE TABLE revision(
    lastChangedRevision  INTEGER NOT NULL,
    backupNeeded         BOOLEAN NOT NULL CHECK((backupNeeded > -1) AND (backupNeeded < 2)));
CREATE TABLE device(
    deviceNo             INTEGER PRIMARY KEY AUTOINCREMENT,
    deviceId             TEXT UNIQUE NOT NULL,
    lastChangedRevision  INTEGER NOT NULL,
    guestNet             BOOLEAN CHECK((guestNet > -1) AND (guestNet < 2)),
    isAuthority          INTEGER,
    isAuthority_conf     INTEGER,
    deviceType           TEXT,
    deviceType_conf      INTEGER,
    manufacturer         TEXT,
    manufacturer_conf    INTEGER,
    modelNumber          TEXT,
    modelNumber_conf     INTEGER,
    serialNumber         TEXT,
    serialNumber_conf    INTEGER,
    firmwareDate         TEXT,
    firmwareDate_conf    INTEGER,
    firmwareVersion      TEXT,
    firmwareVersion_conf INTEGER,
    hardwareVersion      TEXT,
    hardwareVersion_conf INTEGER,
    description          TEXT,
    description_conf     INTEGER,
    operatingSystem      TEXT,
    operatingSystem_conf INTEGER,
    hostName             TEXT,
    hostName_conf        INTEGER,
    friendlyName         TEXT,
    friendlyName_conf    INTEGER,
    lastSeenOnline       INTEGER,
    detectedOnNetwork    TEXT);
CREATE TABLE property(
    name                 TEXT NOT NULL,
    value                TEXT NOT NULL,
    deviceNo             INTEGER NOT NULL REFERENCES device(deviceNo));
CREATE TABLE alias(
    alias                TEXT NOT NULL,
    deviceNo             INTEGER NOT NULL REFERENCES device(deviceNo));
CREATE TABLE interface(
    interfaceNo          INTEGER PRIMARY KEY AUTOINCREMENT,
    macAddr              TEXT UNIQUE NOT NULL COLLATE NOCASE,
    interfaceType        TEXT,
    guestNet             BOOLEAN CHECK((guestNet > -1) AND (guestNet < 2)),
    connectionOnline     BOOLEAN CHECK((connectionOnline > -1) AND (connectionOnline < 2)),
    detectedByDriver     BOOLEAN CHECK((detectedByDriver > -1) AND (detectedByDriver < 2)),
    mu_mimo              BOOLEAN CHECK((mu_mimo > -1) AND (mu_mimo < 2)),
    wifiBand             TEXT,
    connectionType       TEXT,
    ethernetPort         INTEGER,
    parentDeviceId       TEXT,
    remote               BOOLEAN CHECK((remote="") OR ((remote > -1) AND (remote < 2))),
    ap_bssid             TEXT COLLATE NOCASE,
    deviceNo             INTEGER NOT NULL REFERENCES device(deviceNo));
CREATE TABLE ipaddr(
    ip                   TEXT NOT NULL,
    type                 TEXT NOT NULL,
    interfaceNo          INTEGER NOT NULL REFERENCES interface(interfaceNo));
CREATE TABLE ethernet(
    port                 INTEGER UNIQUE NOT NULL,
    linkUp               BOOLEAN CHECK((linkup > -1) AND (linkup < 2)),
    linkSpeed            TEXT);
CREATE TABLE ethernet_macs(
    macAddr              TEXT NOT NULL COLLATE NOCASE,
    port                 INTEGER NOT NULL,
    linkSpeed            TEXT NOT NULL,
    parentDeviceId       TEXT NOT NULL,
    remote               TEXT NOT NULL);
CREATE TABLE wifi_macs(
    macAddr              TEXT NOT NULL COLLATE NOCASE);
CREATE TABLE arp(
    ip                   TEXT NOT NULL,
    type                 TEXT NOT NULL,
    macAddr              TEXT NOT NULL COLLATE NOCASE);
CREATE TABLE mac_reserve(
    macAddr              TEXT NOT NULL COLLATE NOCASE,
    deviceNo             INTEGER NOT NULL REFERENCES device(deviceNo));
CREATE TABLE deleted(
    deviceId             TEXT UNIQUE NOT NULL,
    lastChangedRevision  INTEGER NOT NULL);
CREATE TABLE transient_table(
    tableName            TEXT NOT NULL);
CREATE TABLE transient_attr(
    tableName            TEXT NOT NULL,
    attrName             TEXT NOT NULL,
    defaultValue         TEXT);
INSERT INTO "revision" VALUES('1', '0');
INSERT INTO "transient_table" VALUES('ipaddr');
INSERT INTO "transient_table" VALUES('ethernet');
INSERT INTO "transient_table" VALUES('ethernet_macs');
INSERT INTO "transient_table" VALUES('wifi_macs');
INSERT INTO "transient_table" VALUES('arp');
INSERT INTO "transient_table" VALUES('deleted');
INSERT INTO "transient_attr" VALUES('revision', 'lastChangedRevision', '1');
INSERT INTO "transient_attr" VALUES('revision', 'backupNeeded', '0');
INSERT INTO "transient_attr" VALUES('device', 'lastChangedRevision', '0');
INSERT INTO "transient_attr" VALUES('interface', 'guestNet', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'connectionOnline', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'detectedByDriver', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'mu_mimo', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'wifiBand', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'connectionType', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'ethernetPort', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'parentDeviceId', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'remote', NULL);
INSERT INTO "transient_attr" VALUES('interface', 'ap_bssid', NULL);
COMMIT;
