#!/bin/bash

ORGANIZATION="bancotoyota"
PAT=$az_tkn

OUTPUT_FILE="repositorios.csv"

# Função para URL encode usando jq
function url_encode() {
    local raw="$1"
    echo -n "$raw" | jq -sRr @uri
}

# Função para buscar os projetos
function get_projects() {
    curl -s -u :$PAT \
        "https://dev.azure.com/$ORGANIZATION/_apis/projects?api-version=6.0" | jq -r '.value[] | .name'
}

# Função para buscar os repositórios de um projeto
function get_repositories() {
    local project=$1
    local project_encoded=$(url_encode "$project")
    curl -s -u :$PAT \
        "https://dev.azure.com/$ORGANIZATION/$project_encoded/_apis/git/repositories?api-version=6.0" | jq -r '.value[] | .name'
}

# Criando o arquivo CSV e escrevendo o cabeçalho
echo "nomeProjeto,nomeRepositorio" > $OUTPUT_FILE

# Iterando sobre os projetos e repositórios
IFS=$'\n'
for project in $(get_projects); do
    for repo in $(get_repositories "$project"); do
        echo "$project,$repo" >> $OUTPUT_FILE
    done
done

echo "Arquivo CSV gerado com sucesso: $OUTPUT_FILE"

