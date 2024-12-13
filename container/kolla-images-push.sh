#!/usr/bin/env bash
## Description:
## 推送本机的 kolla-ansible 容器公共镜像(registry_public)到本地私有镜像仓库(registry_private)。
## 可以选择所有(-a)或者指定(-i)容器镜像名称。
## Note：本机的 kolla-ansible 容器公共镜像可以通过 `kolla-ansible -i ./all-in-one pull [--tags=service_name]` 或者 image_get.sh 的 image_pull{} 函数 或者简单使用 docker pull 拉取。

container_engine="docker"
registry_public=quay.io
#registry_private=172.21.6.86:4000
registry_private=10.86.12.11:20200

# Move to top level directory
REAL_PATH=$(python3 -c "import os;print(os.path.realpath('$0'))")
cd "$(dirname "$REAL_PATH")/.."

function process_cmd {
    if [[ -z "$KOLLA_IMAGES" ]]; then
        echo "No images to push, exit now."
        exit 0
    fi

    CMD

    if [[ $? -ne 0 ]]; then
        echo "Command failed"
        exit 1
    fi
}

function usage {
    cat <<EOF
Usage: $0 COMMAND [options]

Options:
    --all, -a                              Push all kolla images
    --dangling                             Push orphaned images
    --help, -h                             Show this usage information
    --image, -i <image>                    Push selected images
    --image-version <image_version>        Set Kolla image version
    --engine, -e <container_engine>        Container engine to be used
EOF
}

SHORT_OPTS="ahi:e:"
LONG_OPTS="all,dangling,help,image:,image-version:,engine:"
ARGS=$(getopt -o "${SHORT_OPTS}" -l "${LONG_OPTS}" --name "$0" -- "$@") || { usage >&2; exit 2; }

for arg do
    shift
    if [ "$arg" = "-e" ] || [ "$arg" = "--engine" ]; then
        container_engine="$1"
        continue
    elif [ "$arg" = "$container_engine" ]; then
        continue
    fi
    eval set -- "$@" "$arg"
done

# catch empty arguments
if [ "$ARGS" = " --" ]; then
    eval set -- "$ARGS"
fi

case "$1" in
    (--all|-a)
            KOLLA_IMAGES="$(sudo ${container_engine} images -a --filter "label=kolla_version" --format "{{.Repository}}:{{.Tag}}" | grep ${registry_public})"
            echo -e "$KOLLA_IMAGES\n"
            [ -n "$KOLLA_IMAGES" ] && KOLLA_IMAGES_POSTFIX=$(echo "$KOLLA_IMAGES" | awk -F'/' '{print $2"/"$3}')
            shift
            ;;
    (--dangling)
            KOLLA_IMAGES="$(sudo ${container_engine} images -a --filter dangling=true --format "{{.ID}}")"
            shift
            ;;
    (--image|-i)
            KOLLA_IMAGES="$(sudo ${container_engine} images -a --filter "label=kolla_version" --format "{{.Repository}}:{{.Tag}}" | grep ${registry_public} | grep -E "$2")"
            echo -e "$KOLLA_IMAGES\n"
            [ -n "$KOLLA_IMAGES" ] && KOLLA_IMAGES_POSTFIX=$(echo "$KOLLA_IMAGES" | awk -F'/' '{print $2"/"$3}')
            shift 2
            ;;
    (--image-version)
            KOLLA_IMAGES="$(sudo ${container_engine} images -a --filter "label=kolla_version=${2}" --format "{{.Repository}}:{{.Tag}}" | grep ${registry_public})"
            [ -n "$KOLLA_IMAGES" ] && KOLLA_IMAGES_POSTFIX=$(echo "$KOLLA_IMAGES" | awk -F'/' '{print $2"/"$3}')
            shift 2
            ;;
    (--help|-h)
            usage
            shift
            exit 0
            ;;
    (--)
            echo -e "Error: no argument passed\n"
            usage
            exit 0
            ;;
esac

CMD() {
  for KOLLA_IMAGES_POSTFIX in $KOLLA_IMAGES_POSTFIX; do
      image_public=${registry_public}/${KOLLA_IMAGES_POSTFIX}
      image_private=${registry_private}/${KOLLA_IMAGES_POSTFIX}
      echo -e "BEGIN: Pushing $image_private ..."
      sudo ${container_engine} tag $image_public $image_private
      sudo ${container_engine} push $image_private
      [ "$?" -eq 0 ] || exit 1
      sudo ${container_engine} rmi $image_private
      echo -e "END: Pushing $image_private done.\n"
  done
}
process_cmd
