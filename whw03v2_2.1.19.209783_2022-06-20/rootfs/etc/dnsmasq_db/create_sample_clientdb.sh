#!/bin/sh

DEFAULT_DBFILE=/tmp/lrhk/clientdb.db
SCHEMA_FILE=/etc/dnsmasq_db/clientdb.sql

create_db()
{
    rm $DEFAULT_DBFILE
    mkdir -p /tmp/lrhk
    sqlite3 $DEFAULT_DBFILE < $SCHEMA_FILE
    chmod 777 $DEFAULT_DBFILE
    chmod 777 /tmp/lrhk
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO AuthList values(7, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO AuthList values(9, 13);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(1, NULL, NULL, NULL, "204.23.05.11", "ipv4", NULL, 13);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(2, NULL, NULL, NULL, "android.clients.google.com", "hostname", NULL, 13);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(3, NULL, NULL, NULL, "mtalk.google.com", "hostname", NULL, 13);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(4, NULL, NULL, NULL, "www.google.com", "hostname", NULL, 13);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(5, NULL, NULL, NULL, "mtalk*", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(6, NULL, NULL, NULL, "*.googleapis.com", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(7, NULL, NULL, NULL, "www.google.com", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(8, NULL, NULL, NULL, "support.google.com", "hostname", NULL, 13);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(9, NULL, NULL, NULL, "support.*.com", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(10, NULL, NULL, NULL, "stackover*.com", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(11, NULL, NULL, NULL, "en.wikipedia.org", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO WANFirewallRule values(12, NULL, NULL, NULL, "*bloomberg.com", "hostname", NULL, 11);'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO MacId values(7, "34:80:b3:f2:25:3a");'
    sqlite3 $DEFAULT_DBFILE 'INSERT INTO MacId values(9, "e0:a3:ac:2c:a6:0b");'
#    sqlite3 $DEFAULT_DBFILE 'INSERT INTO MacId values(9, "e0:a3:ac:2c:a6:0c");'
}

create_db

