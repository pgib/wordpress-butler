# Wordpress Butler

Wordpress has been the subject of numerous exploits over the years, and even if
you've upgraded yourself to the latest and safest version, you may still have
dirt lingering around from previous hacks. This script will find every
installation of Wordpress, and delete entries from your options table that
contains exploitable code.

It also checks the version of each installation to alert you if you need to
upgrade. You can optionally create a tab-delimited report that you can open in
your favourite spreadsheet software.

This script was written for [Retrix Hosting](http://retrix.com/) (of which I am a partner), but we
decided to give it away to anyone who would like to use it for the greater good.

## Requirements

This script was written in standard POSIX shell `#!/bin/sh`, and only tested on
FreeBSD. It should, however, work on the other BSDs, Mac OS X, Linux, etc. Other
requirements include:

* The 'mysql' command-line tool
* grep, sed, awk, tail, find
* The necessary permissions to scan through the folders in $basedir
* The script parses the wp-config.php file for each installation of Wordpress found, and will connect to the database server to gather information and remove offending rows.

