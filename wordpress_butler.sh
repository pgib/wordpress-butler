#!/bin/sh
# $Id: wordpress_butler.sh 5 2009-11-03 06:50:27Z patrickg.com $
#===================================================================
# wordpress_butler.sh                                    version 0.5
#
# A script to connect to every Wordpress database and remove a
# popular backdoor exploit. It also checks the version of any
# found installation of Wordpress and will give you the admin's
# address.
#
# Requirements:
# - The 'mysql' command-line tool.
# - grep, sed, awk, tail
#
# This was developed on FreeBSD. It should work fine in Linux and
# other Unix environments, though it hasn't been tested elsewhere.
#
# Any of the variables defined in this script can be overridden by
# creating ~/.wordpress_backdoor_cleaner.conf and placing them in
# there. Doing so allows you to upgrade this script without losing
# your custom settings.
#
# More information about the exploit can be found here:
#
# http://ottodestruct.com/blog/2009/hacked-wordpress-backdoors/
#
# Additional ideas from the WordPress Exploit Scanner plug-in whose only
# fault is that it requires installation and activation on a per-
# WordPress installation:
#
# http://ocaoimh.ie/exploit-scanner/
#
# by Patrick Gibson <patrick@patrickg.com> http://pgib.me/
#
# written for Retrix Hosting, Inc. <http://retrix.com/>
#===================================================================

# The root directory from which the scan will start
basedir="/usr/home"

# The 'mysql' command-line tool
mysql="`which mysql` --safe-updates=0"

# The latest version of Wordpress available. It would be great if
# we could determine this automatically, but I'm unaware how that
# can be done. For now, you will need to manually update this before
# running the script
latest_wordpress="2.8.5"

# We will create a nice report
#report="no"
report="yes"
report_file="`pwd`/wordpress-version-report.txt"

# If defined, you this callback script will be called for every
# installation found that requires an upgrade
# Usage: $callback_script <blogname> <email> <path> <siteurl> <version> <latest_version>
#callback_script="/path/to/wordpress_upgrade_notifier.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Load the user's configuration file if it exists. The configuration
# file can contain all of the variable defined above, and will
# override the default settings found in this script. The advantage
# of using the configuration file is that you can safely upgrade
# the script without losing any of your custom settings.
if [ -r /$HOME/.wordpress_backdoor_cleaner.conf ]; then
	. /$HOME/.wordpress_backdoor_cleaner.conf
fi


# Based on FreeBSD's /etc/rc.subr
checkyesno()
{
	case $1 in
		#       "yes", "true", "on", or "1"
		[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
		return 0
		;;

		#       "no", "false", "off", or "0"
		[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
		return 1
		;;

		*)
		return 1
		;;
	esac
}

# Start a report file if desired
if checkyesno ${report}; then
	echo "Blog	Email	Path	Version	Upgrade Needed	Suspicious Plugins" > ${report_file}
fi

# look for all wp-config.php files
echo "Beginning scan in $basedir..."
for i in `find $basedir -type f -name wp-config.php`; do

	# extract the database connection information out of wp-config.php
	dbname=`grep -e "^define('DB_NAME" $i | awk '{print $2}' | sed -e "s/[');]//g"`
	dbuser=`grep -e "^define('DB_USER" $i | awk '{print $2}' | sed -e "s/[');]//g"`
	dbpass=`grep -e "^define('DB_PASSWORD" $i | awk '{print $2}' | sed -e "s/[');]//g"`
	dbhost=`grep -e "^define('DB_HOST" $i | awk '{print $2}' | sed -e "s/[');]//g"`
	table_prefix=`grep -e '^\$table_prefix' $i | awk '{print $3}' | sed -e "s/[');]//g"`

	query="select option_value from ${table_prefix}options where option_name='blogname'"
	blogname=`echo ${query} | ${mysql} -u ${dbuser} -p${dbpass} -h ${dbhost} ${dbname} | tail -n 1`

	query="select option_value from ${table_prefix}options where option_name='siteurl'"
	siteurl=`echo ${query} | ${mysql} -u ${dbuser} -p${dbpass} -h ${dbhost} ${dbname} | tail -n 1`

	echo "Checking blog ${blogname} ${siteurl}..."

	/bin/echo -n "+ Removing 'edoced_46esab' entries from ${dbname}/${table_prefix}options... "
	query="delete from ${table_prefix}options where option_value like '%edoced_46esab%'"
	echo ${query} | ${mysql} -u ${dbuser} -p${dbpass} -h ${dbhost} ${dbname};
	if [ $? != 0 ]; then
		echo "[failed]"
		echo "   * Error connecting to ${dbname}. Run this query manually:"
		echo ${query}
	else
		echo "[success]"
	fi

	/bin/echo -n "+ Looking for suspicious active_plugins in ${dbname}/${table_prefix}options... "
	query="select option_value from ${table_prefix}options where option_name='active_plugins' and (option_value like '%jpg%' or option_value like '%..%')"
	result=`echo ${query} | ${mysql} -u ${dbuser} -p${dbpass} -h ${dbhost} ${dbname} | tail -n 1`
	suspicious_plugins="No"
	if [ $? != 0 ]; then
		echo "[failed]"
		echo "   * Error connecting to ${dbname}. Run this query manually:"
		echo ${query}
	else
		if [ -z $result ]; then
			echo "[none found]"
		else
			suspicious_plugins="Yes"
			echo "[found]"
		fi
	fi

	# check to see if this installation needs to be upgraded

	if [ -e `dirname $i`/wp-includes/version.php ]; then
		version_file="`dirname $i`/wp-includes/version.php"
		version=`grep -e '^\$wp_version' ${version_file} | awk '{print $3}' | sed -e "s/[');]//g"`
	else
		version="unknown"
	fi

	if [ $version != $latest_wordpress ]; then
		echo "*ATTENTION* ${blogname} may need an upgrade; it's using Wordpress ${version}, and the latest is ${latest_wordpress}."
		upgrade_needed="Yes"

		query="select user_email from ${table_prefix}users where id=1"
		admin_email=`echo ${query} | ${mysql} -u ${dbuser} -p${dbpass} -h ${dbhost} ${dbname} | tail -n 1`

		echo "Contact ${admin_email} to arrange for the upgrade."

	else
		echo "Excellent. ${blogname} is running the latest Wordpress (${latest_wordpress})"
		upgrade_needed="No"
		admin_email="N/A"
	fi

	if checkyesno ${report}; then
		echo "${blogname}	${admin_email}	`dirname $i`	${version}	${upgrade_needed}	${suspicious_plugins}" >> ${report_file}
	fi

	if checkyesno ${upgrade_needed}; then
		if [ ! -z $callback_script ]; then
			if [ -x $callback_script ]; then
				/bin/echo -n "Running callback script: ${callback_script}... "
				$callback_script "${blogname}" "${admin_email}" "`dirname $i`" "${siteurl}" "${version}" "${latest_wordpress}"
				if [ $? != 0 ]; then
					echo "[failed]"
				else
					echo "[success]"
				fi
			fi
		fi
	fi

	echo

done

if checkyesno ${report}; then
	echo "Tab-delimted report file can be found at ${report_file}."
fi
