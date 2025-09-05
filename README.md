#!/bin/bash
# ==============================================================================
# Script para automatizar a execução do WRF com dados do ERA5
#
# VERSÃO ROBUSTA E EFICIENTE
#
# Funcionalidades:
# - Para o script imediatamente se ocorrer um erro (set -e).
# - Pula etapas do WPS (geogrid, ungrib, metgrid) se os arquivos de
#   saída já existirem.
# - Verifica o sucesso de cada etapa crítica antes de prosseguir.
# - Estrutura de diretórios organizada por data.
# ==============================================================================

# Encerra o script imediatamente se um comando falhar.
set -e

echo ">> 1. CONFIGURANDO AMBIENTE"

# --- CONFIGURAÇÃO MANUAL: AJUSTE ESTES CAMINHOS ---
export PROJECT_ROOT="/path/to/your/era5wrf_project"
export WRF_BASE_DIR="/path/to/your/WRF-Chem_installation"
export GEOG_DATA_PATH="/path/to/your/geog_data"
export SHAPEFILES_DIR="/path/to/your/shapefiles"

# --- Define as datas da simulação ---
if [[ ! -n $1 ]] ; then
    export DATE=$(date -u +%Y%m%d)00
else
    export DATE=$1
fi
# Adiciona 36 horas à data inicial para definir o fim da simulação
export AMANHA=$(date -u -d "${DATE:0:8} ${DATE:8:2}:00:00 UTC +36 hours" +%Y%m%d%H)

# Formata as datas para os namelists do WRF/WPS
DATE_START_WRF=$(echo $DATE | sed 's/\(....\)\(..\)\(..\)\(..\)/\1-\2-\3_\4:00:00/')
DATE_END_WRF=$(echo $AMANHA | sed 's/\(....\)\(..\)\(..\)\(..\)/\1-\2-\3_\4:00:00/')

# --- Define os caminhos e variáveis ---
export WORK_DIR="$PROJECT_ROOT"
export WPS_HOME="$WRF_BASE_DIR/WPS"
export WRF_HOME="$WRF_BASE_DIR/WRF"
export TEMPLATE_DIR="$WORK_DIR/template"

export DOWNLOAD_SCRIPT_PY="$WORK_DIR/download_era5_range.py"

export ERA5_DATA_DIR="$WORK_DIR/gribdata"
export RUN_DIR="$WORK_DIR/run/$DATE"
export WPS_RUN_DIR="$RUN_DIR/wps"
export WRF_RUN_DIR="$RUN_DIR/wrf"

export VTABLE_FILE="Vtable.ECMWF"
export NUM_CORES=30 # Número de processadores para mpirun

# --- Exibe as configurações ---
echo "   - Data de Início: $DATE_START_WRF"
echo "   - Data de Fim...: $DATE_END_WRF"
echo "   - Diretório de Execução: $RUN_DIR"
echo "   - Diretório Geog: ${GEOG_DATA_PATH}"

# --- Cria os diretórios de execução ---
mkdir -p ${WPS_RUN_DIR}
mkdir -p ${WRF_RUN_DIR}

echo ">> 2. OBTENDO DADOS DO ERA5"
python ${DOWNLOAD_SCRIPT_PY} ${DATE} ${AMANHA} ${ERA5_DATA_DIR}
# O script python já verifica se os arquivos existem antes de baixar

# Verifica se os arquivos GRIB estão disponíveis após a chamada do script
PL_FILE=${ERA5_DATA_DIR}/era5_pl_${DATE}_${AMANHA}.grib
SFC_FILE=${ERA5_DATA_DIR}/era5_sfc_${DATE}_${AMANHA}.grib

if [ ! -f "${PL_FILE}" ] || [ ! -f "${SFC_FILE}" ]; then
    echo "❌  ERRO: Arquivos GRIB do ERA5 não encontrados após a verificação."
    exit 1
fi
echo "   - Dados GRIB do ERA5 estão disponíveis."

echo ">> 3. EXECUTANDO WPS (com verificação de arquivos)"
cd ${WPS_RUN_DIR}

# --- Limpa apenas links simbólicos antigos e prepara o ambiente ---
rm -f GRIBFILE.* met_em.* ungrib.log metgrid.log geogrid.log
rm -f geogrid.exe ungrib.exe metgrid.exe link_grib.csh Vtable GEOGRID.TBL METGRID.TBL
ln -sf ${TEMPLATE_DIR}/QNWFA_QNIFA_QNBCA_SIGMA_MONTHLY.dat .
# --- Link dos executáveis e tabelas necessárias ---
ln -sf ${WPS_HOME}/geogrid.exe .
ln -sf ${WPS_HOME}/ungrib.exe .
ln -sf ${WPS_HOME}/metgrid.exe .
ln -sf ${WPS_HOME}/link_grib.csh .
ln -sf ${WPS_HOME}/ungrib/Variable_Tables/${VTABLE_FILE} ./Vtable
ln -sf ${WPS_HOME}/geogrid .
ln -sf ${WPS_HOME}/metgrid .

# --- Configura o namelist.wps ---
cp -rf ${TEMPLATE_DIR}/namelist_chem.wps namelist.wps 
sed -i "s|start_date.*=.*|start_date = '${DATE_START_WRF}', '${DATE_START_WRF}',|g" namelist.wps
sed -i "s|end_date.*=.*|end_date = '${DATE_END_WRF}', '${DATE_END_WRF}',|g" namelist.wps
sed -i "s|geog_data_path.*=.*|geog_data_path = '${GEOG_DATA_PATH}'|g" namelist.wps

# --- Etapa GEOGRID ---
if [ ! -f "geo_em.d01.nc" ]; then
    echo "   - Executando geogrid..."
    ./geogrid.exe > geogrid.log 2>&1
    echo "   - Geogrid concluído com sucesso."
else
    echo "   - Arquivo geo_em.d01.nc já existe. Pulando geogrid."
fi

# --- Etapa UNGRIB ---
if ls FILE:* >/dev/null 2>&1; then
    echo "   - Arquivos 'FILE:*' já existem. Pulando ungrib."
else
    echo "   - Executando ungrib..."
    ./link_grib.csh ${ERA5_DATA_DIR}/* ./ungrib.exe > ungrib.log 2>&1
    if ! ls FILE:* >/dev/null 2>&1; then echo "❌ ERRO: ungrib.exe falhou em criar arquivos 'FILE:*'. Verifique ungrib.log."; exit 1; fi
    echo "   - Ungrib concluído com sucesso."
fi

# --- Etapa METGRID ---
if ls met_em.d*.nc >/dev/null 2>&1; then
    echo "   - Arquivos 'met_em.*' já existem. Pulando metgrid."
else
    echo "   - Executando metgrid..."
    ./metgrid.exe > metgrid.log 2>&1
    if ! ls met_em.d*.nc >/dev/null 2>&1; then echo "❌ ERRO: metgrid.exe falhou em criar arquivos 'met_em.*'. Verifique metgrid.log."; exit 1; fi
    echo "   - Metgrid concluído com sucesso."
fi

echo ">> 4. EXECUTANDO WRF"
cd ${WRF_RUN_DIR}
# ========================================
# ETAPA WRF (Weather Research and Forecasting Model)
# ========================================
echo -e "\n>> 3. INICIANDO ETAPA WRF EM: $WRF_RUN_DIR"
cd "$WRF_RUN_DIR"
# Data inicial
START_YEAR=${DATE:0:4}
START_MONTH=${DATE:4:2}
START_DAY=${DATE:6:2}
START_HOUR=${DATE:8:2}

# Data final
END_YEAR=${AMANHA:0:4}
END_MONTH=${AMANHA:4:2}
END_DAY=${AMANHA:6:2}
END_HOUR=${AMANHA:8:2}


# --- 3.1. real.exe ---
echo "   -> 3.1. Executando real.exe com $NUM_CORES_WRF núcleos"
ln -sf "$WRF_HOME/real.exe" .
ln -sf "$WRF_HOME/wrf.exe" .


# --- Limpa links antigos e prepara o ambiente ---
# Cria links para todos arquivos que batem com os padrões
for pattern in "ozon*" "*TBL*" "*DATA" "C*" "c*" "a*" "b*" "i*" "p3*" "t[e,r]*" ; do
    for file in $TEMPLATE_DIR/$pattern; do
        # Só cria se o arquivo realmente existir
        if [ -e "$file" ]; then
            ln -sf "$file" .
        fi
    done
done
# --- Link dos arquivos do WPS ---
ln -sf ${WPS_RUN_DIR}/met_em.* .

cp -rf $TEMPLATE_DIR/namelist_chem.input namelist.input
# Substitui cada linha relevante no namelist.input
sed -i "/start_year/c\ start_year = ${START_YEAR}, ${START_YEAR}" namelist.input
sed -i "/start_month/c\ start_month = ${START_MONTH}, ${START_MONTH}" namelist.input
sed -i "/start_day/c\ start_day = ${START_DAY}, ${START_DAY}" namelist.input
sed -i "/start_hour/c\ start_hour = ${START_HOUR}, ${START_HOUR}" namelist.input

sed -i "/end_year/c\ end_year = ${END_YEAR}, ${END_YEAR}" namelist.input
sed -i "/end_month/c\ end_month = ${END_MONTH}, ${END_MONTH}" namelist.input
sed -i "/end_day/c\ end_day = ${END_DAY}, ${END_DAY}" namelist.input
sed -i "/end_hour/c\ end_hour = ${END_HOUR}, ${END_HOUR}" namelist.input



ln -sf $WPS_RUN_DIR/met_em.*.nc .
./real.exe

if [[ ! -f "wrfinput_d01" || ! -f "wrfbdy_d01" ]]; then
    echo "❌  ERRO: real.exe falhou. Verifique os arquivos rsl.error.* em $WRF_RUN_DIR"
    exit 1
fi
echo "      ✔️  real.exe concluído com sucesso."

# --- 3.2. wrf.exe ---
echo "   -> 3.2. Executando wrf.exe com $NUM_CORES_WRF núcleos"
mpirun --allow-run-as-root  -n 30 ./wrf.exe

if ! ls wrfout_d01_* 1> /dev/null 2>&1; then
    echo "❌  ERRO: wrf.exe falhou. Verifique os arquivos rsl.error.* em $WRF_RUN_DIR"
    exit 1
fi
echo "      ✔️  wrf.exe concluído com sucesso."

echo ">> 5. ✅ SIMULAÇÃO CONCLUÍDA COM SUCESSO!"
