#!/usr/bin/env python3
# coding=utf-8
import re
import os
import sys
import glob
import time
import optparse
import subprocess

N = int(os.environ.get('N', 2))

commands = {
    "spark": "/usr/lib/spark/bin/beeline -u jdbc:hive2://localhost:10001/%s -n hadoop -f ",
    "presto": "presto --server emr-header-1:9090 --catalog hive --schema %s -f ",
    "hive": "hive --database %s --hiveconf hive.mapred.mode=nonstrict --hiveconf hive.strict.checks.cartesian.product=false -f",
    "hive-mr": "beeline -u jdbc:hive2://emr-header-1:10000/%s -n hadoop --hiveconf hive.execution.engine=tez -f ",
    "hive-tez": "beeline -u jdbc:hive2://emr-header-1:10000/%s -n hadoop --hiveconf hive.execution.engine=mr -f ",
}

queries_dir = os.path.abspath(os.path.join(sys.path[0], "queries"))


def fwrite(filename, data):
    with open(filename, 'w') as fp:
        fp.write(data)


def fread(filename):
    with open(filename, 'r') as fp:
        return fp.read()


def fcall(funcs, *args, **kwargs):
    for f in funcs:
        f(*args, **kwargs)


def sh(*args):
    # print('sh:', args)
    return subprocess.call(*args, shell=True)


def avg(iter):
    return sum(iter) / len(iter)


def elapse(func, *args):
    assert callable(func)
    start = time.time()
    ret = func(*args)
    end = time.time()
    return (end - start), ret


def run(engine, db, fs):
    cmd = commands[engine.lower()] % db
    _, fmt, scale = db.split("_")[:3]
    fname = os.path.join(os.getcwd(), "{engine}.{fmt}.{fs}.{scale}.res".format(
        engine=engine, fmt=fmt, fs=fs, scale=scale))
    res = open(fname, "w")
    fcall([res.write, sys.stdout.write], "# filename, time, status\n")
    queries = glob.glob(os.path.join(queries_dir, "*.sql"))
    queries = sorted(queries, key=lambda n: int(re.findall(r'\d+', n)[0]))

    for q in queries:
        # Get the best result from n rounds
        name = f"{q}.{engine}.{fmt}.{fs}.{scale}"
        cmdl = f"{cmd} {q}"
        fwrite(f"{name}.cmd", cmdl)
        outs = [elapse(sh, f"{cmdl} > {name}.{i}.log 2>&1") for i in range(N)]
        durs = [r[0] for r in outs]
        rets = [r[1] for r in outs]
        success = not any(rets)
        if success:
            status = "success"
        else:
            status = "failed"
        cost = avg(durs)
        if success:
            fwrite(f"{name}.res", str(cost))
        fcall([res.write, sys.stdout.write], "%s %s(%d tries), %f\n" % (os.path.basename(q), status, N, cost))
        fcall([res.flush, sys.stdout.flush])
    res.close()


def main():
    """
    ./run-query.py -g spark -d tpcds_orc_1000,tpcds_parquet_1000 -s juicefs://your-volume-name
    :return:
    """
    parse = optparse.OptionParser()
    parse.add_option('-g', '--engine', dest='engine')
    parse.add_option('-d', '--database', dest='database', default="tpcds_orc_1000,tpcds_parquet_1000")
    parse.add_option('-s', '--filesystem', dest='filesystem')

    (options, args) = parse.parse_args()

    engines = options.engine.split(",")
    databases = options.database.split(",")
    filesystems = options.filesystem.split(",")
    for fs in filesystems:
        fs_name = fs[:fs.index(":")]
        for engine in engines:
            for db in databases:
                print("""
########################################
run queries in %s on %s in %s
########################################
                    """ % (engine, db, fs_name))
                run(engine, db, fs_name)


sys.exit(main() or 0)
