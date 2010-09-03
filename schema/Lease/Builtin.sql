SET SESSION storage_engine = InnoDB;

DROP TABLE IF EXISTS `lease`;
CREATE TABLE `lease`
(
  `lease_id`                            INT UNSIGNED      NOT NULL    auto_increment,
  `ip`                                  INT UNSIGNED      NOT NULL,
  `mac_address`                         CHAR(12)          NOT NULL,
  `status`                              CHAR(20)          NOT NULL,
  `lease_seconds`                       INT UNSIGNED      NOT NULL,
  `ts_assigned`                         DATETIME          NOT NULL,
  `ts_renewal`                          DATETIME          NOT NULL,
  `ts_rebinding`                        DATETIME          NOT NULL,
  `ts_expiration`                       DATETIME          NOT NULL,
  PRIMARY KEY (`lease_id`),
  UNIQUE (`ip`),
  UNIQUE (`mac_address`),
  INDEX (`ts_assigned`),
  INDEX (`ts_renewal`),
  INDEX (`ts_rebinding`),
  INDEX (`ts_expiration`)
);

DROP TABLE IF EXISTS `lease_data`;
CREATE TABLE `lease_data`
(
  `lease_id`                            INT UNSIGNED      NOT NULL,
  `offer`                               BLOB              NOT NULL,
  PRIMARY KEY (`lease_id`)
);

DROP TABLE IF EXISTS `lease_history`;
CREATE TABLE `lease_history`
(
  `lease_history_id`                    INT UNSIGNED      NOT NULL    auto_increment,
  `ip`                                  INT UNSIGNED      NOT NULL,
  `mac_address`                         CHAR(12)          NOT NULL,
  `ts_assigned`                         DATETIME          NOT NULL,
  PRIMARY KEY (`lease_history_id`),
  INDEX (`ip`),
  INDEX (`mac_address`),
  INDEX (`ts_assigned`)
);
