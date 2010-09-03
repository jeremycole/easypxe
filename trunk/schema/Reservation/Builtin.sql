SET SESSION storage_engine = InnoDB;

DROP TABLE IF EXISTS `option_set`;
CREATE TABLE `option_set`
(
  `option_set_id`                       INT UNSIGNED      NOT NULL,
  PRIMARY KEY (`option_set_id`)
);

DROP TABLE IF EXISTS `option`;
CREATE TABLE `option`
(
  `option_id`                           INT UNSIGNED      NOT NULL      auto_increment,
  `option_set_id`                       INT UNSIGNED      NOT NULL,
  `key`                                 CHAR(50)          NOT NULL,
  `value`                               CHAR(100)         NOT NULL,
  PRIMARY KEY (`option_id`),
  INDEX (`option_set_id`)
);

DROP TABLE IF EXISTS `network`;
CREATE TABLE `network`
(
  `network_id`                          INT UNSIGNED      NOT NULL      auto_increment,
  `network`                             INT UNSIGNED      NOT NULL,
  `netmask`                             INT UNSIGNED      NOT NULL,
  PRIMARY KEY (`network_id`)
);

DROP TABLE IF EXISTS `network_uses_option_set`;
CREATE TABLE `network_uses_option_set`
(
  `network_id`                          INT UNSIGNED      NOT NULL,
  `option_set_id`                       INT UNSIGNED      NOT NULL,
  PRIMARY KEY (`network_id`, `option_set_id`)
);

DROP TABLE IF EXISTS `reservation`;
CREATE TABLE `reservation`
(
  `network_id`                          INT UNSIGNED      NOT NULL,
  `ip`                                  INT UNSIGNED      NOT NULL,
  `mac_address`                         CHAR(12)          NOT NULL,
  PRIMARY KEY (`network_id`, `ip`),
  UNIQUE (`ip`),
  INDEX (`mac_address`)
);