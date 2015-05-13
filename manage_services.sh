#!/bin/bash

LOGGER='src/http_logging/http_logging_server.py'
ADAPTER='src/adapters/AdapterServer.py'
CONTROLLER='src/ControllerServer.py'

SERVICES=(LOGGER ADAPTER CONTROLLER)

#PID_FILE='/var/run/ads.pid'
PID_FILE='ads.pid'

# Correct usage of the script and its valid
# arguments.
# COMMENT: Usage should try to print help in the format of well-known, conventional unix
# utilities. Please see help of any unix utility.
usage() {
  echo "Usage:"
  echo "Valid Services : LOGGER, ADAPTER and CONTROLLER"
  echo "1. For starting all the services:"
  echo " a) ./manage_services.sh"
  echo " b) ./manage_services.sh start"
  echo "2. For stopping all the services:"
  echo "./manage_services.sh stop"
  echo "3. For an individual start or stop:"
  echo "./manage_services.sh start SERVICE1"
  echo "./manage_services.sh stop SERVICE1 SERVICE2"
}

# To check if the service entered by the user
# is valid or not.
in_array() {
  local n=$#
  local value=${!n}
  for ((i=1; i < $#; i++)) {
    if [ "${!i}" == "${value}" ]; then
      # in shell 0 is success
      echo 0
      exit 0
      #return 0
    fi
  }
  echo 1
  #return 1
  exit 1
}

# Start the services.
start_service() {
  if [[ ! -f $PID_FILE ]]; then
    touch $PID_FILE
  fi
  # If no specific services are mentioned,
  # start all the services.
  if [ -z "$args" ]; then
    #echo "Starting all services."
    #for service in $SERVICES; do
    #  echo $service
    #  #python $service &
    #  #echo "SERVICE NAME:$!" >> $PID_FILE
    #  #sleep 1
    #done

    python $LOGGER &
    # The variable "$!" has the PID of the last
    # background process started.
    echo "LOGGER:$!" >> $PID_FILE
    sleep 1
    python2 $ADAPTER &
    echo "ADAPTER:$!" >> $PID_FILE
    sleep 1
    python2 $CONTROLLER &
    echo "CONTROLLER:$!" >> $PID_FILE

  else
    # Start the specific services mentioned
    # by the user.
    for arg in $args; do
      if [[ $(in_array "${SERVICES[@]}" "$arg") != 0 ]]; then
        echo "Invalid service name: $arg."
        usage
        exit 1;
      else
        # Since the services ex. LOGGER are stored inside input arguments, it
        # is tricky to extract a variable name from a variable.  This has been
        # done here using "${!arg}" syntax. Refer
        # http://www.linuxquestions.org/questions/programming-9/bash-how-to-get-variable-name-from-variable-274718/
        # for more.
        python ${!arg} &
        echo "$arg:$!" >> $PID_FILE
        sleep 1
      fi
    done
  fi
}

# Stop the services.
stop_service() {
  # If no specific service is mentioned,
  # stop all the services.
  if [ -z "$args" ]; then
    if [ -f $PID_FILE ]; then
      for i in `cat $PID_FILE`; do
        pid=$(echo $i | cut -d ":" -f 2)
        kill $pid
      done
      rm $PID_FILE
      echo "Stopped all services."
    else
      echo "No services are running to be stopped."
    fi

  else
    # Stop only the service(s) mentioned by
    # the user.
    for arg in $args; do
      if [ -f $PID_FILE ]
      then
        for process in `cat $PID_FILE`; do
          process_name=`echo $process | cut -d ":" -f 1`
          pid=`echo $process | cut -d ":" -f 2`
          if [[ $process_name == $arg ]]; then
            kill $pid;
            echo "Stopping service $arg."
            sed -i /$process_name/d $PID_FILE
            echo "Stopped services."
          fi
        done
      else
        echo "No services are running to be stopped."
      fi
    done
  fi
}

# Start mongod service.
start_mongod() {
  service mongodb start
}

# Stop mongod service.
stop_mongod() {
  service mongodb stop
}

# Repair mongod service.
repair_mongod() {
  mongodb --repair
}

# Check if the service mongod is already running.
pre_check() {
  service mongodb status
  if [ $? -ne 0 ]
  then
    echo 'service mongod is not running'
    stop_mongod
    echo 'stopping mongod'
    repair_mongod
    echo 'restarting mongod'
    start_mongod
    echo 'service mongod successfully restarted'
  fi
}

# If the script is executed alone, all the services
# are started.
# COMMENT: why are you using a string comparison - shouldn't it be a number?
#if [ $# == 0 ]
if [ $# -eq '0' ]; then
  pre_check
  # COMMENT: why do you assume that to start a service we need to stop it
  # first? Shouldn't restart should do that.
  stop_service
  start_service
  exit 0;

# This is the help option, to view the correct
# usage of the script and its valid arguments.
elif [[ $1 == "-h" || $1 == "--help" ]]; then
  usage
  exit 0;

# If arguments are greater than or equal to 1
# other than help. This means that the user has
# entered specific services to be started/stopped.
else
  input_args=($@)
  action=${input_args[0]}
  args=${input_args[@]:1}

  if [ "$action" == "start" ]; then
    pre_check
    # COMMENT: why do you assume that to start a service we need to stop it
    # first? Shouldn't restart should do that.
    stop_service "$args"
    start_service "$args"
    exit 0;

  elif [ "$action" == "stop" ]; then
    stop_service "$args"
    exit 0;

  else
    echo "Error: Invalid action."
    usage
    exit 1;
  fi
fi
