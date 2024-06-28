#!/bin/bash
##########################################################################
# Obj: Criar TaskGroup a partir de um taskGroup exportado (JSON)
#       - PAT (az_tkn)
#	- Arquivo de TaskGroup
# By: Bruno Miquelini (bruno.santos@yaman.com.br)
# Data: 28/06/2024
#########################################################################

project_name=""
taskgroup_name="Deploy Openshift - HELM"
taskgroup_description="Deploy de aplicações no Openshift utilizando Helm Chart"
az_tkn=$az_tkn
json_file=""

bar() {
  echo
  echo
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
}

# Helper
usage() {
  bar
  echo "[!!] Ajuda de como utilizar a automação..."
  echo "Uso: $0 -p <project-name> -k <az-tkn> -f <json-file>"
  bar
  exit 1
}

while getopts "p:t:d:k:f:" opt; do
  case ${opt} in
    p ) project_name=$OPTARG ;;
    t ) taskgroup_name=$OPTARG ;;
    d ) taskgroup_description=$OPTARG ;;
    k ) az_tkn=$OPTARG ;;
    f ) json_file=$OPTARG ;;
    * ) usage ;;
  esac
done

if [ -z "$project_name" ] || [ -z "$az_tkn" ] || [ -z "$json_file" ]; then
  usage
fi

if [ ! -f "$json_file" ]; then
  bar
  echo "[!!] Arquivo  '$json_file' não encontrado."
  exit 1
fi

encoded_project_name=$(echo -n "$project_name" | jq -sRr @uri)
organization="bancotoyota"
url="https://dev.azure.com/$organization/$encoded_project_name/_apis/distributedtask/taskgroups?api-version=6.0-preview.1"
response=$(curl -s -u :$az_tkn -H "Content-Type: application/json" "$url")
existing_taskgroup=$(echo "$response" | jq --arg name "$taskgroup_name" '.value[] | select(.name == $name)')

if [ -n "$existing_taskgroup" ]; then
  bar
  echo "[!!] TaskGroup $taskgroup_name ja existe no projeto $project_name."
  bar
  exit 0
fi

response=$(curl -s -u :$az_tkn -H "Content-Type: application/json" -X POST -d @"$json_file" "$url")

if echo "$response" | jq -e '.id' >/dev/null; then
  bar
  echo "[+] Task Group $taskgroup_name criado com sucesso no projeto $project_name."
  bar
else
  bar
  echo "[-] Falha ao criar o Taskgroup. Resposta: $response"
  bar
  exit 1
fi

