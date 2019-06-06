#!/usr/bin/env bash


if [ $# -eq 0 ]; then
    echo "No command passed, redirecting logs to stdout and stderr"
    ln -nsf /dev/stdout /var/log/apache2/access.log
    ln -nsf /dev/stderr /var/log/apache2/error.log
    ln -nsf /dev/stderr /var/log/apache2/other_vhosts_access.log
    ln -nsf /dev/stdout /var/log/mysql.log
    ln -nsf /dev/stderr /var/log/mysql.err
#    ln -nsf /dev/stdout /var/log/cron.log
fi


echo "starting Syslog NG"
service  syslog-ng start

echo "Starting MariaDb"
mysqld_safe &
MYSQL_PID=$!

echo "Starting Apache"
apachectl -DFOREGROUND &
APACHE_PID=$!

echo "Starting at"
/usr/sbin/atd &
AT_PID=$!

echo "**************************************************"
echo "* LAMP Server is ready "
echo "* Server IP address is $(hostname -i) "
echo "**************************************************"

run-parts /etc/start

if [ $# -ne 0 ]; then
    echo "running ${@}"
    exec "$@"
fi