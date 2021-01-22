#!/usr/bin/env bash

''':'
__dir="$(cd "$(dirname $0)";pwd)"
PATH=$PATH:/usr/local/bin:$HOME/.local/bin
PYTHON=`command -v python3`
if [ -z $PYTHON ]; then
    echo "no Python3 available, please install it first"
    exit 1
fi
if [[ ! -f $HOME/.local/bin/termgraph ]]; then
    $PYTHON -m pip install termgraph --user
fi
sudo juicefs auth $JFS_VOL \
    --token $(grep juicefs.token /etc/hadoop/conf/core-site.xml -A1 | grep value | sed -e 's/<[^>]*>//g' -e 's/\s//g') \
    --accesskey="" \
    --secretkey=""
exec $PYTHON $0 "$@"
exit $?
'''  # '''

import os
import re
import sys
import glob
import time
import argparse
import subprocess
from datetime import datetime


__dir__ = os.path.dirname(os.path.realpath(__file__))
INIT_THRIFT_SERVER_BIN = os.path.join(__dir__, 'init-thriftserver.sh')
RUN_QUERY_BIN = os.path.join(__dir__, 'run-query.py')
TPCDS_SETUP_BIN = os.path.join(__dir__, 'tpcds-setup.sh')
TERMGRAPH_BIN = os.environ.get('TERMGRAPH_BIN', 'termgraph')
QUERIES_DIR = os.path.join(__dir__, 'queries')
COLORS = {
    'jfs': 'green',
    's3': 'red',
    'emrfs': 'red',
    'hdfs': 'blue',
}


def printH(s):
    print('#' * 20)
    print('# ' + s)
    print('#' * 20)


def elapse(func, *args, **kwargs):
    assert callable(func)
    start = time.time()
    ret = func(*args, **kwargs)
    end = time.time()
    return (end - start), ret


def require_input(msg):
    if not sys.stdin.isatty():
        return ''
    return input(msg + ": ").strip()


def fwrite(filename, data):
    with open(filename, 'w') as fp:
        fp.write(data)


def fread(filename):
    with open(filename, 'r') as fp:
        return fp.read()


def sh(*args):
    return subprocess.check_call(*args, shell=True)


def mkres(queries, key, fs_protocols, filename, get_name_func=lambda x: x):
    assert iter(queries)
    assert iter(fs_protocols)
    assert callable(get_name_func)
    with open(filename, 'w') as fp:
        label = ','.join(fs_protocols)
        fp.write('# %s %s\n' % (filename, label))
        fp.write('@ %s\n' % label)
        for q in queries:
            resfile = [get_name_func(q, key, ptcl) for ptcl in fs_protocols]
            if not all(os.path.isfile(r) for r in resfile):
                continue
            q = os.path.basename(q)
            d = ','.join('%.2f' % float(fread(r)) for r in resfile)
            fp.write('%s,%s\n' % (q, d))


def mkplot(queries, key, fs_protocols, filename, get_name_func):
    mkres(queries, key, fs_protocols, filename, get_name_func)
    title = '%s %s unit(sec)' % (key, ' vs '.join(fs_protocols))
    color = ' '.join(COLORS.get(t, 'magenta') for t in fs_protocols)
    sh(' '.join([
        TERMGRAPH_BIN,
        filename,
        ('--color %s' % color) if len(fs_protocols) > 1 else '',
        '--title "%s"' % title,
    ]))


def cleanup_benchmark_data(uri, scale, fs_proto):
    printH(f'cleaning benchmark data {uri} {scale} {fs_proto}')
    sh(f'hadoop fs -rm -r -f {uri}/tmp/tpcds-orc/{scale}')
    sh(f'hadoop fs -rm -r -f {uri}/tmp/tpcds-parquet/{scale}')
    sh(f'hadoop fs -rm -r -f {uri}/tmp/tpcds-generate/{scale}')
    sh(f'''\
        hive -e "
        drop database if exists tpcds_parquet_{scale}_{fs_proto} cascade;
        drop database if exists tpcds_orc_{scale}_{fs_proto} cascade;
        drop database if exists tpcds_text_{scale}_{fs_proto} cascade;
        " || true
    ''')


def gen_benchmark_data(uri, scale, fs_proto, restore=False):
    if not os.path.isfile(os.path.join(__dir__, 'target/tpcds-gen-1.0-SNAPSHOT.jar')):
        printH('compile target/tpcds-gen-1.0-SNAPSHOT.jar from source')
        sh(f'''
            cd {__dir__}
            sudo yum -y install java-1.8.0-openjdk-devel maven git gcc make flex bison byacc curl unzip patch
            make -C tpcds-gen
            cp -rvf tpcds-gen/target/ .
        ''')
    printH(f'generating benchmark data {uri} {scale} {fs_proto}')
    mode = 'RESTORE' if restore else 'LOAD'
    t, _ = elapse(sh, f'{TPCDS_SETUP_BIN} {scale} {uri} {fs_proto} {mode}')
    fwrite(f'{TPCDS_SETUP_BIN}.{fs_proto}.{scale}.res', str(t))


def run_query(uri, scale, fs_proto, cleanup=False, gendata=True, restore=False, engine='spark'):
    if cleanup:
        cleanup_benchmark_data(uri, scale, fs_proto)
    if gendata:
        if restore:
            print('Trying to restore database')
        gen_benchmark_data(uri, scale, fs_proto, restore)

    if engine == 'spark':
        printH('init thriftserver')
        sh(INIT_THRIFT_SERVER_BIN)
    else:
        printH('stop thriftserver')
        sh('sudo /usr/lib/spark/sbin/stop-thriftserver.sh')

    printH(f'run {engine} queries {scale} {fs_proto}')
    sh(f'{RUN_QUERY_BIN} -g {engine} -d tpcds_parquet_{scale}_{fs_proto},tpcds_orc_{scale}_{fs_proto} -s {uri}')


def main():
    class NegateAction(argparse.Action):
        def __call__(self, parser, ns, values, option):
            setattr(ns, self.dest, option[2:4] != 'no')

    parser = argparse.ArgumentParser(description='run emr benchmark all in one')
    parser.add_argument('--engine', dest='engine', default='spark', nargs='?', choices=['hive', 'spark'])
    parser.add_argument('--show-plot-only', dest='show_plot_only', action='store_true', default=False,
                        help='will show plot only if set')
    parser.add_argument('--cleanup', '--no-cleanup', dest='cleanup', action=NegateAction, default=False, nargs=0,
                        help='whether to clean up benchmark existing data')
    parser.add_argument('--gendata', '--no-gendata', dest='gendata', action=NegateAction, default=True, nargs=0,
                        help='whether to generate benchmark data')
    parser.add_argument('--restore', dest='restore', action='store_true', default=False,
                        help='whether to restore the benchmark database from existing data')
    parser.add_argument('--scale', metavar='N', type=int, nargs='?', default=2,
                        help='an integer for the accumulator')
    parser.add_argument('--s3', '--no-s3', dest='s3', action=NegateAction, default=False, nargs=0,
                        help='whether to enable s3 benchmark')
    parser.add_argument('--jfs', '--no-jfs', dest='jfs',  action=NegateAction, default=False, nargs=0,
                        help='whether to enable jfs benchmark')
    parser.add_argument('--hdfs', '--no-hdfs', dest='hdfs', action=NegateAction, default=False, nargs=0,
                        help='whether to enable hdfs benchmark')

    args = parser.parse_args()

    now = datetime.now()
    nowstr = now.strftime('%Y-%m-%d_%H-%M-%S')
    scale = args.scale
    s3_uri = ''
    jfs_uri = ''
    hdfs_uri = ''
    fs_protocols = []

    if args.jfs:
        jfs_uri = 'jfs://%s/' % (os.environ.get('JFS_VOL')
                                 or require_input('Enter your JuiceFS volume name for benchmark'))
        fs_protocols.append('jfs')

    if args.s3:
        s3_bucket = require_input('Enter your S3 bucket name for benchmark. Will create it if it doesn\'t exist')
        s3_uri = 's3://%s/' % s3_bucket

        sh(f'''\
        if ! aws s3api head-bucket --bucket="{s3_bucket}"; then
            echo "{s3_bucket} not exist, create it firstly"
            aws s3 mb {s3_uri}
        fi
        ''')
        fs_protocols.append('s3')

    if args.hdfs:
        hdfs_uri = 'hdfs://$(hostname)/'
        fs_protocols.append('hdfs')

    if not args.show_plot_only:
        if args.jfs:
            run_query(jfs_uri, scale, 'jfs',
                      cleanup=args.cleanup,
                      gendata=args.gendata,
                      restore=args.restore,
                      engine=args.engine)
        if args.s3:
            run_query(s3_uri, scale, 's3',
                      cleanup=args.cleanup,
                      gendata=args.gendata,
                      restore=args.restore,
                      engine=args.engine)
        if args.hdfs:
            run_query(hdfs_uri, scale, 'hdfs',
                      cleanup=args.cleanup,
                      gendata=args.gendata,
                      restore=args.restore,
                      engine=args.engine)

    if len(fs_protocols):
        queries = glob.glob(os.path.join(QUERIES_DIR, '*.sql'))
        queries = sorted(queries, key=lambda n: int(re.findall(r'\d+', n)[0]))

        def tpcds_setup_res_name(query, key, fs_proto):
            return f'tpcds-setup.sh.{fs_proto}.{scale}.res'

        def query_sql_res_name(query, key, fs_proto):
            return f'{query}.{key}.{fs_proto}.{scale}.res'

        mkplot(['tpcds-setup.sh'], 'tpcds-setup.sh duration', fs_protocols,
               filename=f'tpcds-setup-{scale}-duration.{nowstr}.res',
               get_name_func=tpcds_setup_res_name)
        mkplot(queries, f'{args.engine}.parquet', fs_protocols,
               filename=f'{args.engine}-parquet-{scale}-benchmark.{nowstr}.res',
               get_name_func=query_sql_res_name)
        mkplot(queries, f'{args.engine}.orc', fs_protocols,
               filename=f'{args.engine}-orc-{scale}-benchmark.{nowstr}.res',
               get_name_func=query_sql_res_name)
    else:
        print('nothing to do')


if __name__ == "__main__":
    sys.exit(main() or 0)
