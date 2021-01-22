#!/bin/bash

path="$(cd "$(dirname $0)";pwd)"
cd ${path}

export HADOOP_CLASSPATH=$(hadoop classpath)

function usage {
    echo "Usage: tpcds-setup.sh scale_factor fs db suffix mode"
    exit 1
}

function runcommand {
    echo $1
    $1
}

# Get the parameters.
SCALE=$1
FS=$2
DB_SUFFIX=$3
MODE=$4

if [[ "X$DEBUG_SCRIPT" != "X" ]]; then
    set -x
fi

# Sanity checking.
if [[ X"$SCALE" = "X" ]]; then
    usage
fi
if [[ X"$FS" = "X" ]]; then
    FS=hdfs://
fi
if [[ X"$DB_SUFFIX" = "X" ]]; then
    DB_SUFFIX=`echo ${FS} | grep -o -P '[a-z0-9]+(?=:)'`
fi

DIR=${FS}/tmp/tpcds-generate

if [[ ${SCALE} -eq 1 ]]; then
    echo "Scale factor must be greater than 1"
    exit 1
fi

sudo /usr/lib/spark/sbin/stop-thriftserver.sh

# Do the actual data load.
hadoop fs -mkdir -p ${DIR}
hadoop fs -ls ${DIR}/${SCALE} > /dev/null
if [[ $? -ne 0 ]]; then
    echo "Generating data at scale factor $SCALE."
    (hadoop jar target/tpcds-gen-1.0-SNAPSHOT.jar -d ${DIR}/${SCALE}/ -s ${SCALE})
fi
hadoop fs -ls ${DIR}/${SCALE} > /dev/null
if [[ $? -ne 0 ]]; then
    echo "Data generation failed, exiting."
    exit 1
fi

hadoop fs -chmod -R 777  ${DIR}/${SCALE}

echo "TPC-DS text data generation complete."

SPARK_SQL="spark-sql"

if [[ "X$SPARK_HOME" != "X" ]]; then
    SPARK_SQL="$SPARK_HOME/bin/spark-sql"
fi

CORE_NODES=$(yarn node -list -showDetails | grep -i 'Total Nodes' | sed -r 's/.*:([[:digit:]]+).*/\1/')
VCORES=$(yarn node -list -showDetails | grep "Configured Resources" | head -1 | sed -r 's/.*vCores:([[:digit:]]+).*/\1/')
TOTAL_MEM=$(yarn node -list -showDetails | grep "Configured Resources" | head -1 | sed -r 's/.*memory:([[:digit:]]+).*/\1/')
EXEC_MEM=$(printf "%.0f" $(bc <<< "${TOTAL_MEM} * 0.8"))

echo "core nodes: ${CORE_NODES}, vcores: ${VCORES}, total mem: ${TOTAL_MEM}m, exec mem: ${EXEC_MEM}m"

SPARK_SQL="${SPARK_SQL}
--master yarn
--executor-memory ${EXEC_MEM}m
--executor-cores ${VCORES}
--num-executors ${CORE_NODES}
--hiveconf hive.optimize.sort.dynamic.partition=true
--hiveconf hive.exec.max.dynamic.partitions=100000
--hiveconf hive.exec.max.dynamic.partitions.pernode=3000
--hiveconf hive.exec.dynamic.partition.mode=nonstrict
--conf spark.sql.parquet.writeLegacyFormat=true
"

hive -e "show databases;" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Failed to connect hive."
    exit 1
fi

set -e

# Create the text/flat tables as external tables. These will be later be converted to Parquet.
echo "Create external text file tables:"
runcommand "hive -f ${path}/scripts/external.sql --hivevar db=tpcds_text_${SCALE}_${DB_SUFFIX} --hivevar location=${DIR}/${SCALE}"

echo "Create Parquet tables:"
runcommand "hive -f ${path}/scripts/parquet.sql --hivevar db_parquet=tpcds_parquet_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX} --hivevar location=${FS}/tmp/tpcds-parquet/${SCALE}"

# echo "Create Parquet no partition tables:"
# runcommand "hive -f ${path}/scripts/parquet_no_partition.sql --hivevar db_parquet=tpcds_parquet_no_partition_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX} --hivevar location=${FS}/tmp/tpcds-parquet-no-partition/${SCALE}"

echo "Create orc tables:"
runcommand "hive -f ${path}/scripts/orc.sql --hivevar db_orc=tpcds_orc_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX} --hivevar location=${FS}/tmp/tpcds-orc/${SCALE}"

# echo "Create orc no partition tables:"
# runcommand "hive -f ${path}/scripts/orc_no_partition.sql --hivevar db_orc=tpcds_orc_no_partition_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX} --hivevar location=${FS}/tmp/tpcds-orc-no-partition/${SCALE}"

if [[ "$MODE" = "LOAD" ]]; then
    echo "Load Parquet tables:"
    runcommand "$SPARK_SQL -f ${path}/scripts/insert.sql --hivevar db_parquet=tpcds_parquet_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX}"

#    echo "Load Parquet no partition tables:"
#    runcommand "$SPARK_SQL -f ${path}/scripts/insert_parquet_no_partition.sql --hivevar db_parquet=tpcds_parquet_no_partition_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX}"

    echo "Load orc tables:"
    runcommand "$SPARK_SQL -f ${path}/scripts/insert_orc.sql --hivevar db_orc=tpcds_orc_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX}"

#    echo "Load orc no partition tables:"
#    runcommand "$SPARK_SQL -f ${path}/scripts/insert_orc_no_partition.sql --hivevar db_orc=tpcds_orc_no_partition_${SCALE}_${DB_SUFFIX} --hivevar db_txt=tpcds_text_${SCALE}_${DB_SUFFIX}"
else
    echo "Repair parquet tables:"
    hive --database tpcds_parquet_${SCALE}_${DB_SUFFIX} -e "msck repair table catalog_returns; msck repair table catalog_sales; msck repair table inventory; msck repair table store_returns; msck repair table store_sales; msck repair table web_returns; msck repair table web_sales;"
    echo "Repair orc tables:"
    hive --database tpcds_orc_${SCALE}_${DB_SUFFIX} -e "msck repair table catalog_returns; msck repair table catalog_sales; msck repair table inventory; msck repair table store_returns; msck repair table store_sales; msck repair table web_returns; msck repair table web_sales;"
fi



