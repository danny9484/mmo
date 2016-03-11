CREATE TABLE IF NOT EXISTS "mmo" (
	`id`	INTEGER PRIMARY KEY,
	`name` TEXT,
	`exp` INTEGER,
	`health` INTEGER,
	`health_before` INTEGER,
	`strength` INTEGER,
	`agility` INTEGER,
	`luck` INTEGER,
	`intelligence` INTEGER,
	`magic` INTEGER,
	`magic_max` INTEGER,
	`endurance` INTEGER,
	`skillpoints` INTEGER,
	`battlelog` INTEGER,
	`statusbar` INTEGER,
	`fraction` INTEGER,
	`level` INTEGER
);

CREATE TABLE IF NOT EXISTS "temptable" (
	`id`	INTEGER PRIMARY KEY,
	`name` TEXT,
	`exp` INTEGER,
	`health` INTEGER,
	`health_before` INTEGER,
	`strength` INTEGER,
	`agility` INTEGER,
	`luck` INTEGER,
	`intelligence` INTEGER,
	`magic` INTEGER,
	`magic_max` INTEGER,
	`endurance` INTEGER,
	`skillpoints` INTEGER,
	`battlelog` INTEGER,
	`statusbar` INTEGER,
	`fraction` INTEGER,
	`level` INTEGER
);

INSERT INTO "temptable" SELECT DISTINCT * FROM "mmo" GROUP BY `id`;

DROP TABLE "mmo";
CREATE TABLE IF NOT EXISTS "mmo" (
	`id`	INTEGER PRIMARY KEY,
	`name` TEXT,
	`exp` INTEGER,
	`health` INTEGER,
	`health_before` INTEGER,
	`strength` INTEGER,
	`agility` INTEGER,
	`luck` INTEGER,
	`intelligence` INTEGER,
	`magic` INTEGER,
	`magic_max` INTEGER,
	`endurance` INTEGER,
	`skillpoints` INTEGER,
	`battlelog` INTEGER,
	`statusbar` INTEGER,
	`fraction` INTEGER,
	`level` INTEGER
);
INSERT INTO "mmo" SELECT * FROM "temptable";
DROP TABLE "temptable"
