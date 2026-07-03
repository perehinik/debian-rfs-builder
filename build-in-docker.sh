#!/bin/bash
set -e

DOCKER_IMAGE=perehiniak/linux-build-tools:1.0.0

POSTINST_SCRIPT_PATH="./postinst/postinst.sh"

while getopts "x:v:h" opt; do
    case $opt in
        x)
            POSTINST_SCRIPT_PATH=$OPTARG
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

POSTINST_SCRIPT_NAME=$(basename ${POSTINST_SCRIPT_PATH})
POSTINST_SCRIPT_DIR=$(dirname ${POSTINST_SCRIPT_PATH})

if [ -f "${POSTINST_SCRIPT_PATH}" ]; then
    # Just mount postinst over default postinst
    POSTINST_SCRIPT_OPTION="-v ${POSTINST_SCRIPT_DIR}/:/root/postinst"
fi

echo "'${POSTINST_SCRIPT_OPTION}'"

docker run -it \
        --rm \
        --privileged \
        -v ./:/root \
	${POSTINST_SCRIPT_OPTION} \
        -w /root \
        -u root \
        --entrypoint ./build.sh \
        ${DOCKER_IMAGE}\
	"$@" \
	-x "./postinst/${POSTINST_SCRIPT_NAME}"
