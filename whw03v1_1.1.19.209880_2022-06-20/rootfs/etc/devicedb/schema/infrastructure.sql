PRAGMA foreign_keys=ON;
BEGIN TRANSACTION;
CREATE TABLE infrastructure(
    infrastructure       BOOLEAN NOT NULL,
    infrastructureType   TEXT,
    deviceNo             INTEGER NOT NULL REFERENCES device(deviceNo));
COMMIT;
