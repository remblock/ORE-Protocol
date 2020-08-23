# Gracefully Stop ORE-Protocol

nodeos_pid=$(pgrep nodeos)

if [ ! -z "$nodeos_pid" ]; then
  if ps -p $nodeos_pid > /dev/null; then
    kill -SIGINT $nodeos_pid
  fi
  while ps -p $nodeos_pid > /dev/null; do
   sleep 1
  done
fi

echo "ORE-Protocol Stopped"
