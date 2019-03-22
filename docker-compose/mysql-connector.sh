#!/bin/bash
BASE_PATH=$(dirname $0)

echo "Waiting 60 seconds for mysql to get up"
# Give 60 seconds for master and slave to come up
sleep 60

echo "Create MySQL Servers (master / slave repl)"
echo "-----------------"


echo "* Create replication user"

mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'STOP SLAVE;';
mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'RESET SLAVE ALL;';

mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%';"
mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'flush privileges;'


echo "* Set MySQL01 as master on MySQL02"

MYSQL01_Position=$(eval "mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
echo $MYSQL01_Position

MYSQL01_File=$(eval "mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")
echo $MYSQL01_File

MASTER_IP=$(eval "getent hosts $MYSQL_MASTER_HOST|awk '{print \$1}'")
echo $MASTER_IP

mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "CHANGE MASTER TO master_host='$MYSQL_MASTER_HOST', master_port=3306, \
        master_user='$MYSQL_REPLICATION_USER', master_password='$MYSQL_REPLICATION_PASSWORD', master_log_file='$MYSQL01_File', \
        master_log_pos=$MYSQL01_Position;"

echo "* Set MySQL02 as master on MySQL01"

MYSQL02_Position=$(eval "mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
echo $MYSQL02_Position

MYSQL02_File=$(eval "mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")
echo $MYSQL02_File

SLAVE_IP=$(eval "getent hosts $MYSQL_SLAVE_HOST|awk '{print \$1}'")
echo $SLAVE_IP

mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CHANGE MASTER TO master_host='$MYSQL_SLAVE_HOST', master_port=3306, \
        master_user='$MYSQL_REPLICATION_USER', master_password='$MYSQL_REPLICATION_PASSWORD', master_log_file='$MYSQL02_File', \
        master_log_pos=$MYSQL02_Position;"

echo "* Start Slave on both Servers"
mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "start slave;"

echo "Increase the max_connections to 2000"
mysql --host $MYSQL_MASTER_HOST -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'set GLOBAL max_connections=2000';
mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'set GLOBAL max_connections=2000';

mysql --host $MYSQL_SLAVE_HOST -uroot -p$MYSQL_SLAVE_PASSWORD -e "show slave status \G"

echo "MySQL servers created!"
echo "--------------------"
echo
echo Variables available fo you :-
echo
echo MYSQL01_IP       : $MYSQL_MASTER_HOST
echo MYSQL02_IP       : $MYSQL_SLAVE_HOST