#!/bin/bash

DOCKER_IMAGE=debian-rfs-builder:1.0.1
USER_SCRIPT_DIR=""
USER_STEPS_SCRIPT="steps-user.sh"
USER_SCRIPT_OPTION=""

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") -d <directory>"
    echo ""
    echo "Options:"
    echo "  -d <directory>   Specify the directory where '${USER_STEPS_SCRIPT}' is located."
    echo "  -h               Show this help message."
    echo ""
    echo "Note: The script '$USER_STEPS_SCRIPT' must be present and executable in the specified directory."
}

# Parse options
while getopts "d:h" opt; do
    case $opt in
        d)
            USER_SCRIPT_DIR=$OPTARG
            ;;
        h)
            show_help
            exit 0
            ;;
        \?)
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

# Check if the specified directory exists
if [ -n "$USER_SCRIPT_DIR" ] && [ -d "$USER_SCRIPT_DIR" ]; then
    USER_SCRIPT_OPTION="-v ${USER_SCRIPT_DIR}:/root/user_steps"
fi

# Check if USER_STEPS_SCRIPT is present and executable in the specified directory
USER_STEPS_PATH="$USER_SCRIPT_DIR/$USER_STEPS_SCRIPT"
if [ ! -x "$USER_STEPS_PATH" ]; then
    echo "Error: '$USER_STEPS_SCRIPT' is not found or is not executable in the directory '$USER_SCRIPT_DIR'."
    exit 1
fi

# Build docker image if it's not present
if [ -z "$(docker images -q ${DOCKER_IMAGE} 2> /dev/null)" ]; then
  docker build . -t ${DOCKER_IMAGE}
fi

docker run -it \
	--rm \
	--privileged \
	-v ./aarch64-minimal:/root \
	${USER_SCRIPT_OPTION} \
	-w /root \
	-u root \
	--entrypoint ./steps.sh \
	${DOCKER_IMAGE}

mv -f ./aarch64-minimal/rootfs.img ./
