SET SESSION storage_engine = InnoDB;

DROP TABLE IF EXISTS `pool`;
CREATE TABLE `pool`
(
  `network_id`                          INT UNSIGNED      NOT NULL,
  `ip`                                  INT UNSIGNED      NOT NULL,
  `mac_address_last_offered`            CHAR(12)          NULL,
  `ts_last_offered`                     DATETIME          NULL,
  PRIMARY KEY (`network_id`, `ip`),
  UNIQUE (`ip`),
  INDEX(`mac_address_last_offered`),
  INDEX(`ts_last_offered`)
);