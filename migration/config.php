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

// Passwort aus Secret-File lesen
$password_file = getenv('MOODLE_DB_PASSWORD_FILE');
if ($password_file && file_exists($password_file)) {
    $CFG->dbpass = trim(file_get_contents($password_file));
} else {
    // Fallback auf direkte Umgebungsvariable
    $CFG->dbpass = getenv('MOODLE_DB_PASSWORD');
}

$CFG->prefix    = 'mdl_';

require_once(__DIR__ . '/lib/setup.php');