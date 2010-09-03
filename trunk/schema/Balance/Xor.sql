SET SESSION storage_engine = InnoDB;

DROP TABLE IF EXISTS `server`;
CREATE TABLE `server`
(
  `server_identifier`                   INT UNSIGNED      NOT NULL,
  `hostname`                            CHAR(64)          NOT NULL,
  `ts_online`                           DATETIME          NULL,
  `ts_offline`                          DATETIME          NULL,
  `ts_ping`                             DATETIME          NULL,
  PRIMARY KEY (`server_identifier`)
);

DROP TABLE IF EXISTS `server_claim`;
CREATE TABLE `server_claim`
(
  `claim`                               INT UNSIGNED      NOT NULL,
  `server_identifier`                   INT UNSIGNED      NOT NULL,
  PRIMARY KEY (`claim`)
);
