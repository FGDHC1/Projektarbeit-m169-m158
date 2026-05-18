<?php

unset($CFG);
global $CFG;
$CFG = new stdClass();

// Webadresse
$CFG->wwwroot = 'http://localhost';

// Pfade
$CFG->dataroot = '/var/moodledata';
$CFG->directorypermissions = 0777;

// Datenbank Einstellungen 
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST');
$CFG->dbname    = getenv('MOODLE_DB_NAME');
$CFG->dbuser    = getenv('MOODLE_DB_USER');
$CFG->dbpass    = getenv('MOODLE_DB_PASSWORD');
$CFG->prefix    = 'mdl_';

// Optional
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

require_once(__DIR__ . '/lib/setup.php');