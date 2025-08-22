#!/bin/bash
# ==============================================================================
# Script para automatizar a execução do modelo WRF com dados do ERA5
#
# Etapas:
# 1. Configuração de datas e diretórios.
# 2. Download dos dados ERA5 via script Python.
# 3. Execução do WPS (geogrid, ungrib, metgrid).
# 4. Execução do WRF (real, wrf).
# ==============================================================================

# --- Início das Configurações do Usuário ---

# Defina a data e hora para a rodada do modelo no formato yyyymmddhh
# Esta variável será exportada para o script Python usar.
export DATE=2024052000

# Defina o número de processadores para o paralelismo
export NP=4

# Caminho para os diretórios principais do WRF e WPS
# AJUSTE ESTES CAMINHOS PARA A SUA INSTALAÇÃO
WPS_DIR=/path/to/your/WPS
WRF_DIR=/path/to/your/WRF/run

# Caminho para o diretório de dados estáticos do geogrid
# AJUSTE ESTE CAMINHO
GEOG_DATA_PATH=/path/to/yur/geog_data

# Caminho para o script Python que baixa os dados
# AJUSTE ESTE CAMINHO
DOWNLOAD_SCRIPT=/path/to/your/download_era5_oper.py

# --- Fim das Configurações do Usuário ---


# --- 1. Preparação e Limpeza ---

echo "============================================================"
echo "Iniciando o processo para a data: ${DATE}"
echo "============================================================"

# Navega para o diretório do WPS
cd ${WPS_DIR} || { echo "Diretório do WPS não encontrado!"; exit 1; }

echo "Limpando arquivos antigos do WPS..."
./clean -a

# --- 2. Download dos Dados ERA5 ---

echo "============================================================"
echo "Passo 2: Baixando dados do ERA5..."
echo "============================================================"

# Verifica se o script de download existe
if [ ! -f "${DOWNLOAD_SCRIPT}" ]; then
    echo "Erro: Script de download não encontrado em ${DOWNLOAD_SCRIPT}"
    exit 1
fi

# Executa o script Python para baixar os dados
python ${DOWNLOAD_SCRIPT}

# Verifica se o download foi bem-sucedido (checa a existência dos arquivos)
GRIB_DIR=/home/jovyan/arquivos/era5/gribdata
PL_FILE=${GRIB_DIR}/era5_pl_${DATE}.grib
SFC_FILE=${GRIB_DIR}/era5_sfc_${DATE}.grib

if [ ! -f "${PL_FILE}" ] || [ ! -f "${SFC_FILE}" ]; then
    echo "Erro: Falha no download dos arquivos GRIB do ERA5."
    exit 1
fi

echo "Download dos dados ERA5 concluído."

# --- 3. Execução do WPS ---

# 3.1. Linkar o namelist.wps
echo "============================================================"
echo "Passo 3.1: Configurando o namelist.wps"
echo "============================================================"
# O namelist.wps deve ser ajustado para refletir as datas da simulação.
# Exemplo de como ajustar as datas com 'sed' (descomente e ajuste se necessário):
# START_DATE="'${DATE:0:4}-${DATE:4:2}-${DATE:6:2}_${DATE:8:2}:00:00'"
# sed -i "s/^ start_date.*
