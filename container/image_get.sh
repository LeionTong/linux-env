#!/usr/bin/env bash
## Description: 指定镜像名称，实现拉取docker镜像到私有仓库(image_get)或者单纯拉取镜像到本地(image_pull)。

docker_namespace=openstack.kolla
openstack_release=2023.2
# kolla_base_distro=rocky
kolla_base_distro=ubuntu
# kolla_base_distro_version=9
kolla_base_distro_version=jammy
openstack_tag="${openstack_release}-${kolla_base_distro}-${kolla_base_distro_version}"
image_tag=${openstack_tag}
#docker_registry_public=""
docker_registry_public=quay.io
#docker_registry_private=localhost:4000
docker_registry_private=10.86.12.11:20200

function docker_image_pull {
    echo "Pulling image: $docker_image_public"
    if docker images -q "$docker_image_public" | grep -q .; then
        echo "Image already exists locally: $docker_image_public"
    elif ! docker pull "$docker_image_public"; then
        echo "Failed to pull image: $docker_image_public"
        return 1
    fi
}

function docker_image_tag {
    echo "Tagging image: $docker_image_public -> $docker_image_private"
    if ! docker tag "$docker_image_public" "$docker_image_private"; then
        echo "Failed to tag image: $docker_image_public -> $docker_image_private"
        return 1
    fi
}

function docker_image_push {
    echo "Pushing image: $docker_image_private"
    if ! docker push "$docker_image_private"; then
        echo "Failed to push image: $docker_image_private"
        return 1
    fi
}

function docker_image_remove {
    echo "Removing image: $docker_image_private"  
    if ! docker rmi "$docker_image_private"; then  
        echo "Failed to remove image: $docker_image_private"  
        return 1  
    fi
}

function image_get {
  if [ "$#" -eq 0 ]; then
    echo "Usage: image_get <image_name1> [image_name2] ..."
    return 1
  fi

  for image_name in "$@"; do
    IMAGE="${docker_namespace}/${image_name}:${image_tag}"
    docker_image_public="${docker_registry_public}/${IMAGE}"
    docker_image_private="${docker_registry_private}/${IMAGE}"

    echo "Getting image: $docker_image_public"
    docker_image_pull
    docker_image_tag
    docker_image_push
    docker_image_remove
  done
}

function image_pull {
  if [ "$#" -eq 0 ]; then
    echo "Usage: image_pull <image_name1> [image_name2] ..."
    return 1
  fi

  for image_name in "$@"; do
    IMAGE="${docker_namespace}/${image_name}:${image_tag}"
    docker_image_public="${docker_registry_public}/${IMAGE}"

    echo "Getting image: $docker_image_public"
    docker_image_pull
  done
}
