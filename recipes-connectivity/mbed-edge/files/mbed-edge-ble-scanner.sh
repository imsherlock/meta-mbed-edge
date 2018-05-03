#!/bin/sh

PROTOCOL_TRANSLATOR_NAME=ble-scanner
CORE_PORT=22223
CORE_HOST="127.0.0.1"
CORE_HTTP_PORT=8080

#Load optional configuration from /etc/default
test ! -r /etc/default/mbed-edge-client.sh || . /etc/default/mbed-edge-client.sh

NAME=ble-scanner
PIDFILE=/var/run/$NAME.pid
LOGFILE=/var/log/$NAME.log
DAEMON=/opt/arm/ble-scanner
DAEMON_OPTS="--host=$CORE_HOST --port=$CORE_PORT --protocol-translator-name=$PROTOCOL_TRANSLATOR_NAME"

start() {
  hciattach ttymxc2 bcm43xx 3000000 flow -t 20
  hciconfig hci0 up
  hciconfig hci0 name 'warp7 bluetooth'
  hciconfig hci0 piscan

  if [ "$ENABLE_COREFILES" == 1 ]; then
    echo "Enabling coredumps for "$NAME
    ulimit -c unlimited
  fi
  echo -n "Starting daemon: "$NAME
  #ble-scanner can't be started before edge-core is up & running, try three times to start the ble-scanner
  for i in 0 1 2
  do
    #try to get the status from the ble-scanner status api to check if it has started
    wget -qO- 127.0.0.1:$CORE_HTTP_PORT/status &> /dev/null
    if [ $? -eq 0 ]; then
      #edge-core will be launched into a new shell, where it's output is directed to a log file
      # start-stop-daemon --start --quiet --make-pidfile --pidfile $PIDFILE --background --exec /bin/sh -- -c "$DAEMON $DAEMON_OPTS >> $LOGFILE 2>&1"
      echo " - done"
      return 0
    fi
    sleep 3
  done
  echo " - FAILED"
}

stop() {
  echo -n "Stopping daemon: "$NAME
  #kill both the shell and the ble-scanner running in it
  bashPID=$(cat $PIDFILE); [ -n "$bashPID" ] && pkill -P "$bashPID"
  start-stop-daemon --stop --quiet --oknodo --pidfile $PIDFILE
  rm $PIDFILE
  echo " - done"

  hciconfig hci0 down
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    echo "Usage: $0 {start|stop}"
esac

