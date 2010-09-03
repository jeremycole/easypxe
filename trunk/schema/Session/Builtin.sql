SET SESSION storage_engine = InnoDB;

DROP TABLE IF EXISTS `session`;
CREATE TABLE `session`
(
  `mac_address`                         CHAR(12)          NOT NULL,
  `protocol`                            CHAR(5)           NOT NULL,
  `state`                               CHAR(20)          NOT NULL,
  `xid`                                 INT UNSIGNED      NOT NULL,
  `server_identifier`                   INT UNSIGNED      NOT NULL,
  `ip`                                  INT UNSIGNED      NULL,
  `ts_first_seen`                       DATETIME          NOT NULL,
  `ts_last_seen`                        DATETIME          NOT NULL,
  PRIMARY KEY (`mac_address`),
  INDEX (`xid`),
  INDEX (`state`),
  INDEX (`ip`),
  INDEX (`ts_first_seen`),
  INDEX (`ts_last_seen`)
);
