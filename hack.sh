#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit

function wait_condition {
  cond=$1
  timeout=$2

  for ((i=0; i<timeout; i+=5)) do
    echo "Waiting for ${i}s condition: \"$cond\""
    if eval $cond > /dev/null 2>&1; then echo "Conditon met"; return 0; fi;
    sleep 5
  done

  echo "Condition timeout"
  return 1
}

function install {
  if [[ $(minikube config get vm-driver | grep virtualbox) ]]; then
    minikube ssh "sudo mkdir -p /mnt/sda1/mypath"
  else
    sudo mkdir -p /mnt/sda1/osd
  fi

  helm install rook-ceph . --set mon.count=1,\
filesystem.metaReplicas=1,\
filesystem.dataReplicas=1,\
filesystem.podAntiAffinity=false,\
blockstorage.replicas=1,nodes[0].hostname=$(kubectl get nodes -o jsonpath='{.items[].metadata.name}'),\
nodes[0].directories[0].path=/mnt/sda1/osd

  wait_condition "kubectl get cephclusters.ceph.rook.io -A | grep Created" 300
}

function uninstall {
  helm uninstall rook-ceph
  wait_condition "! kubectl get ns | grep rook-ceph" 180

  if [[ $(minikube config get vm-driver | grep virtualbox) ]]; then
    minikube ssh "sudo rm -rf /var/lib/rook"; minikube ssh "sudo rm -rf /mnt/sda1/mypath"; 
  else
    sudo rm -rf /var/lib/rook
    sudo rm -rf /mnt/sda1/mypath
  fi
}

case "${1:-}" in
i)
  install
  ;;
u)
  uninstall
  ;;
t)
  helm template .
  ;;
*)
  echo "usage:" >&2
  echo "  $0 i   install" >&2
  echo "  $0 u   uninstall" >&2
  echo "  $0 t   template" >&2
  ;;
esac
