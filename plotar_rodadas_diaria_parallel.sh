#!/bin/bash
set -e

# ==============================================================================
# SCRIPT MESTRE PARA A RODADA DIÁRIA DO MODELO WRF E PUBLICAÇÃO NA WEB (PARALELO)
#
# Agora usando GNU parallel para explorar múltiplos CPUs (até 60 simultâneos).
# ==============================================================================

echo "=================================================="
echo "INICIANDO RODADA DIÁRIA (PARALELA): $(date)"
echo "=================================================="

# --- INICIALIZAÇÃO DO AMBIENTE CONDA ---
echo "-> Ativando ambiente Conda: wrfpython"
export CONDA_INSTALL_PATH="/opt/conda/"

if [ -f "${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh" ]; then
    source "${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh"
else
    echo "❌ ERRO: Script de inicialização do Conda não encontrado em ${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh"
    exit 1
fi

conda activate wrfpython 
if [[ $? -ne 0 ]]; then
    echo "❌ ERRO: Falha ao ativar o ambiente Conda 'wrfpython'."
    exit 1
fi
echo "✔️ Ambiente Conda 'wrfpython' ativado com sucesso."

export MPLBACKEND=Agg
export PYTHONWARNINGS="ignore::UserWarning"
# --- CONFIGURAÇÃO DE DATA ---
if [[ ! -n $1 ]] ; then
    export DATE=$(date -u +%Y%m%d)00
else
    export DATE=$1
fi
echo "-> Data da rodada definida para: ${DATE}"

# --- CONFIGURAÇÃO DE CAMINHOS E VARIÁVEIS ---
WRF_INPUT_DIR="//home/jovyan/arquivos/era5/run/${DATE}/wrf"
WEB_OUTPUT_DIR="//home/jovyan/arquivos/html/era5/${DATE}"
DOMAINS_TO_PLOT=("d01" "d02")
ALL_VARIABLES=(
    "slp"
    "mcape"
    "mcin"
    "pw"
    "winds"
    "ppn"
    "mdbz"
    "helicity"
    "updraft_helicity"
    "ctt"
    "high_cloudfrac"
    "low_cloudfrac"
    "mid_cloudfrac"
    "u_pvo"
    "u_winds"
    "u_temp"
)

MAX_JOBS=60  # Número máximo de jobs paralelos

echo "-> Verificando diretório de entrada: ${WRF_INPUT_DIR}"
if [ ! -d "$WRF_INPUT_DIR" ]; then
    echo "❌ ERRO: Diretório de entrada não encontrado para a data $WRF_INPUT_DIR ."
    exit 1
fi
cd "$WRF_INPUT_DIR"

echo "-> Limpando e criando diretório de saída: ${WEB_OUTPUT_DIR}"
mkdir -p "$WEB_OUTPUT_DIR"

CONFIG_JS_FILE="${WEB_OUTPUT_DIR}/config.js"
echo "const simulationConfig = {" > "$CONFIG_JS_FILE"

# ==============================================================================
# LOOP DE DOMÍNIOS
# ==============================================================================
for domain in "${DOMAINS_TO_PLOT[@]}"; do
    echo -e "\n--- Processando Domínio: ${domain} ---"
    wrf_file=$(ls wrfout_${domain}_* 2>/dev/null | head -n 1)
    if [[ -z "$wrf_file" ]]; then
        echo "⚠️ AVISO: Nenhum arquivo wrfout encontrado para o domínio ${domain}. Pulando."
        continue
    fi
    echo "  -> Arquivo de entrada: ${wrf_file}"
    
    echo "    '${domain}': {" >> "$CONFIG_JS_FILE"
    
    num_frames=$(ncdump -h "$wrf_file" | grep 'Time = ' | sed 's/.* = \(.*\).*/\1/' | tr -d ';')
    echo "        totalFrames: ${num_frames}," >> "$CONFIG_JS_FILE"
    echo "        variables: [" >> "$CONFIG_JS_FILE"

    commands=()

    for variable in "${ALL_VARIABLES[@]}"; do
        domain_output_dir="${WEB_OUTPUT_DIR}/${domain}/${variable}"
        mkdir -p "$domain_output_dir"
        echo "  -> Preparando variável '${variable}'..."

        if [[ "$domain" = 'd02' ]] ; then
            shapefile='/home/jovyan/arquivos/scripts_previsao_UFSC/BR_SC_RS_d02/BR_SC_RS_d02.shp' 
        else
            shapefile='/home/jovyan/arquivos/scripts_previsao_UFSC/SC_RS_d01/SC_RS_d01.shp' 
        fi

        # Pula se já existe saída
        if compgen -G "${domain_output_dir}/${variable}_*.png" > /dev/null; then
            echo "  ✅ Arquivos já existem para '${variable}', pulando."
            echo "            '${variable}'," >> "$CONFIG_JS_FILE"
            continue
        fi

        # Adiciona comando para execução paralela
        commands+=("wrfplot --shapefile $shapefile --input ${wrf_file} --vars ${variable} --ulevels '900,500,200' --output ${domain_output_dir}")
    done

    # Executa todos os wrfplot deste domínio em paralelo
    if [ ${#commands[@]} -gt 0 ]; then
        printf "%s\n" "${commands[@]}" | parallel -j $MAX_JOBS
    fi

    # Após todos terminarem, renomeia os arquivos
    for variable in "${ALL_VARIABLES[@]}"; do
        domain_output_dir="${WEB_OUTPUT_DIR}/${domain}/${variable}"
        if compgen -G "${domain_output_dir}/${domain}_${variable}_*.png" > /dev/null; then
            echo "     - Renomeando arquivos de saída de ${variable}..."
            pushd "$domain_output_dir" > /dev/null
            for file in ${domain}_${variable}_*.png; do
                [ -f "$file" ] && mv -- "$file" "${file#${domain}_}"
            done
            popd > /dev/null
            echo "            '${variable}'," >> "$CONFIG_JS_FILE"
        fi
    done

    echo "        ]" >> "$CONFIG_JS_FILE"
    echo "    }," >> "$CONFIG_JS_FILE"
done

echo "};" >> "$CONFIG_JS_FILE"

echo -e "\n-> Desativando ambiente Conda."
conda deactivate

echo -e "\n-> Ajustando permissões finais para o diretório web..."
chmod -R 755 "$WEB_OUTPUT_DIR"

echo "=================================================="
echo "RODADA DIÁRIA (PARALELA) CONCLUÍDA: $(date)"
echo "=================================================="

