set -eo pipefail
BASEDIR=$(dirname $(readlink -f $0))/..

LOG_FILE="${BASEDIR}/scripts/install.log"
LIBEVENT_VERSION="2.1.12-stable"
ZOOKEEPER_VERSION="3.5.9-p3"

function run() {
    echo ">>> $@ (${PWD})" | tee -a ${LOG_FILE}
    $@ 2>&1 | tee -a ${LOG_FILE}
}

function configure_make_install() { # $1: path, $2: configure_option
    pushd $1
    run ./configure $2
    run make
    run make install
    popd
}

if [ -n "$1" ]; then
    run mkdir -p $1
    PREFIX=$(readlink -f $1)
    cat /dev/null > ${LOG_FILE}
    echo "TARGET PATH: ${PREFIX}" | tee -a ${LOG_FILE}
else
    echo "[WARNING] No installation target path was given."
    echo "[WARNING] arcus-memcached will be installed in system path and will need root privileges."
    echo "[WARNING] Otherwise, you can consider run below:"
    echo -e "\n        $0 /target/path\n"
    read -p "Do you want to continue installing to system path? [yN]: " yn
    case $yn in
        [Yy]* ) ;;
        * ) exit -1;;
    esac
    cat /dev/null > ${LOG_FILE}
    echo "TARGET PATH: (system)" | tee -a ${LOG_FILE}
fi

pushd ${BASEDIR}/deps
# install libevent
run tar -zxf libevent-${LIBEVENT_VERSION}.tar.gz
configure_option="--disable-openssl"
if [ -n "${PREFIX}" ]; then configure_option+=" --prefix=${PREFIX}"; fi
configure_make_install "libevent-${LIBEVENT_VERSION}" "${configure_option}"
run ./configure "libevent-${LIBEVENT_VERSION}" "${configure_option}"

# install libzookeeper
run tar -zxf arcus-zookeeper-${ZOOKEEPER_VERSION}.tar.gz
configure_option=""
if [ -n "${PREFIX}" ]; then configure_option+=" --prefix=${PREFIX}"; fi
configure_make_install "arcus-zookeeper-${ZOOKEEPER_VERSION}" "${configure_option}"

# install memcached
configure_option="--enable-zk-integration"
if [ -n "${PREFIX}" ]; then configure_option+=" --prefix=${PREFIX} --with-libevent=${PREFIX} --with-zookeeper=${PREFIX}"; fi
configure_make_install ${BASEDIR} "${configure_option}"

echo -e "\n\narcus-memcached installation complete. Now you can run the command below:\n"
echo "    ${PREFIX}/bin/memcached -E ${PREFIX}/lib/default_engine.so -v"