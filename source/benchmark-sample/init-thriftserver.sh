#!/bin/sh
set -e

sudo mkdir -p /var/log/spark/
sudo chmod -R 777 /var/log/spark/

/usr/lib/spark/sbin/stop-thriftserver.sh

CORE_NODES=$(yarn node -list -showDetails | grep -i 'Total Nodes' | sed -r 's/.*:([[:digit:]]+).*/\1/')
VCORES=$(yarn node -list -showDetails | grep "Configured Resources" | head -1 | sed -r 's/.*vCores:([[:digit:]]+).*/\1/')
TOTAL_MEM=$(yarn node -list -showDetails | grep "Configured Resources" | head -1 | sed -r 's/.*memory:([[:digit:]]+).*/\1/')
EXEC_MEM=$(printf "%.0f" $(bc <<< "${TOTAL_MEM} * 0.8"))

echo "core nodes: ${CORE_NODES}, vcores: ${VCORES}, total mem: ${TOTAL_MEM}m, exec mem: ${EXEC_MEM}m"

/usr/lib/spark/sbin/start-thriftserver.sh \
  --master yarn \
  --driver-memory 8g \
  --executor-memory ${EXEC_MEM}m \
  --executor-cores ${VCORES} \
  --num-executors ${CORE_NODES} \
  --conf spark.locality.wait=100 \
  --conf spark.sql.adaptive.enabled=false \
  --conf spark.sql.crossJoin.enabled=true \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.sql.dataprefetch.filescan.schemes='s3,s3n,jfs,hdfs'

until /usr/lib/spark/bin/beeline -u jdbc:hive2://localhost:10001/ -n hadoop -e "show databases;" >/dev/null 2>&1
do
    echo "wait thriftserver to be available"
    sleep 5
done
