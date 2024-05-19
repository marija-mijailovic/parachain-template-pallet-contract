#!/bin/bash

ZOMBIENET_V=v1.3.68
# POLKADOT_V=v1.1.0 not work
POLKADOT_V=v1.0.0
POLKADOT_BIN=polkadot
POLKADOT_PARACHAIN_V=v1.0.0
POLKADOT_PARACHAIN_BIN=polkadot-parachain

case "$(uname -s)" in
Linux*) MACHINE=Linux ;;
Darwin*) MACHINE=Mac ;;
*) exit 1 ;;
esac

if [ $MACHINE = "Linux" ]; then
    ZOMBIENET_BIN=zombienet-linux-x64
elif [ $MACHINE = "Mac" ]; then
    ZOMBIENET_BIN=zombienet-macos
fi

build_polkadot() {
    echo "cloning polkadot repository..."
    CWD=$(pwd)
    mkdir -p bin
    pushd /tmp
    git clone https://github.com/paritytech/polkadot
    pushd polkadot
    git checkout $POLKADOT_V
    echo "building polkadot executable..."
    cargo build --release --features fast-runtime
    cp target/release/polkadot "$CWD/bin"
    #cp target/release/polkadot-execute-worker "$CWD/bin"
    #cp target/release/polkadot-prepare-worker "$CWD/bin"
    popd
    popd
}

build_polkadot_parachain() {
    echo "cloning polkadot repository..."
    CWD=$(pwd)
    mkdir -p bin
    pushd /tmp
    git clone https://github.com/paritytech/cumulus
    pushd cumulus
    git checkout $POLKADOT_V
    echo "building polkadot parachain executable..."
    cargo build --release --bin polkadot-parachain
    cp target/release/polkadot-parachain "$CWD/bin"
    #cp target/release/polkadot-execute-worker "$CWD/bin"
    #cp target/release/polkadot-prepare-worker "$CWD/bin"
    popd
    popd
}

zombienet_init() {
    if [ ! -f $ZOMBIENET_BIN ]; then
        echo "fetching zombienet executable..."
        curl -LO https://github.com/paritytech/zombienet/releases/download/$ZOMBIENET_V/$ZOMBIENET_BIN
        chmod +x $ZOMBIENET_BIN
    fi
    #  if [ ! -f bin/polkadot ] || [ ! -f bin/polkadot-execute-worker ] || [ ! -f bin/polkadot-prepare-worker ]; then
    #    build_polkadot
    #  fi
    if [ ! -f bin/polkadot ]; then
        build_polkadot
    fi
    if [ ! -f bin/polkadot-parachain ]; then
        build_polkadot_parachain
    fi
}

zombienet_spawn() {
    zombienet_init
    if [ ! -f target/release/parachain-template-node ]; then
        echo "building parachain-template-node..."
        cargo build --release
    fi
    echo "spawning polkadot-local relay chain plus parachain-template-node..."
    ./$ZOMBIENET_BIN spawn zombienet-config/integration-tests-config.toml -p native
}

print_help() {
    echo "This is a shell script to automate the execution of zombienet."
    echo ""
    echo "$ ./zombienet.sh init         # fetches zombienet and polkadot executables"
    echo "$ ./zombienet.sh spawn        # spawns a rococo-local relay chain plus parachain-template-node"
}

SUBCOMMAND=$1
case $SUBCOMMAND in
"" | "-h" | "--help")
    print_help
    ;;
*)
    shift
    zombienet_${SUBCOMMAND} $@
    if [ $? = 127 ]; then
        echo "Error: '$SUBCOMMAND' is not a known SUBCOMMAND." >&2
        echo "Run './zombienet.sh --help' for a list of known subcommands." >&2
        exit 1
    fi
    ;;
esac
