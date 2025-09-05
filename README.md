### Documentação do Repositório `era5wrf`

Este repositório contém um conjunto de scripts e ferramentas para automatizar a execução do modelo meteorológico WRF (Weather Research and Forecasting) com dados de reanálise ERA5, gerando produtos de previsão e publicando-os em uma página web.

#### **1. Configuração do Ambiente e Instalação**

Para começar a usar o era5 , o primeiro passo é configurar seu ambiente de trabalho.
 pip install cdsapi
colocar o arquivo com senha $HOME/.cdsapirc
__
url: https://cds.climate.copernicus.eu/api
key: *********************************
___

##### **1.1. Instalação do WRF-Chem**
Este projeto requer que o modelo WRF-Chem já esteja instalado. Recomenda-se utilizar o script de instalação automatizado disponível no repositório `WRF-Install-Script`. O script foi projetado para instalar o WRF-Chem e todas as bibliotecas necessárias em sistemas baseados em Debian e Ubuntu.
* Clone o repositório de instalação: `git clone https://github.com/bakamotokatas/WRF-Install-Script.git`
* Para instalar a versão WRF-Chem, navegue até o diretório e execute o script com a opção `-chem`, por exemplo, para a versão 4.6.1:
    `bash WRF4.6.1_Install.bash -chem`

##### **1.2. Conteúdo do Diretório `template/`**
O diretório `template/` é crucial para a execução dos scripts. Ele contém todos os arquivos de configuração, tabelas e dados estáticos que o WRF e o WPS necessitam para rodar corretamente. Esses arquivos não estão incluídos neste repositório e devem ser obtidos separadamente a partir dos WRF/test. A lista completa de arquivos necessários é:

* `aerosol.formatted`
* `aerosol_lat.formatted`
* `aerosol_lon.formatted`
* `aerosol_plev.formatted`
* `BROADBAND_CLOUD_GODDARD.bin`
* `bulkdens.asc_s_0_03_0_9`
* `bulkradii.asc_s_0_03_0_9`
* `CAM_ABS_DATA`
* `CAM_AEROPT_DATA`
* `CAMtr_volume_mixing_ratio`
* `CAMtr_volume_mixing_ratio.A1B`
* `CAMtr_volume_mixing_ratio.A2`
* `CAMtr_volume_mixing_ratio.RCP4.5`
* `CAMtr_volume_mixing_ratio.RCP6`
* `CAMtr_volume_mixing_ratio.RCP8.5`
* `CAMtr_volume_mixing_ratio.SSP119`
* `CAMtr_volume_mixing_ratio.SSP126`
* `CAMtr_volume_mixing_ratio.SSP245`
* `CAMtr_volume_mixing_ratio.SSP370`
* `CAMtr_volume_mixing_ratio.SSP585`
* `capacity.asc`
* `CLM_ALB_ICE_DRC_DATA`
* `CLM_ALB_ICE_DFS_DATA`
* `CLM_ASM_ICE_DRC_DATA`
* `CLM_ASM_ICE_DFS_DATA`
* `CLM_DRDSDT0_DATA`
* `CLM_EXT_ICE_DRC_DATA`
* `CLM_EXT_ICE_DFS_DATA`
* `CLM_KAPPA_DATA`
* `CLM_TAU_DATA`
* `CCN_ACTIVATE.BIN`
* `co2_trans`
* `coeff_p.asc`
* `coeff_q.asc`
* `constants.asc`
* `create_p3_lookupTable_1.f90-v5.4`
* `create_p3_lookupTable_2.f90-v5.3`
* `eclipse_besselian_elements.dat`
* `ETAMPNEW_DATA`
* `ETAMPNEW_DATA.expanded_rain`
* `ETAMPNEW_DATA.expanded_rain_DBL`
* `ETAMPNEW_DATA_DBL`
* `geo_em.d01.nc`
* `geo_em.d02.nc`
* `GENPARM.TBL`
* `gribmap.txt`
* `grib2map.tbl`
* `HLC.TBL`
* `ishmael-gamma-tab.bin`
* `ishmael-qi-qc.bin`
* `ishmael-qi-qr.bin`
* `kernels.asc_s_0_03_0_9`
* `kernels_z.asc`
* `LANDUSE.TBL`
* `link_grib.csh`
* `masses.asc`
* `MPTABLE.TBL`
* `namelist.input`
* `namelist.wps`
* `namelist_chem-Copy1.wps`
* `namelist_chem.input`
* `namelist_chem.wps`
* `ozone.formatted`
* `ozone_lat.formatted`
* `ozone_plev.formatted`
* `p3_lookupTable_1.dat-v5.4_2momI`
* `p3_lookupTable_1.dat-v5.4_3momI`
* `p3_lookupTable_2.dat-v5.3`
* `README.namelist`
* `README.physics_files`
* `README.rasm_diag`
* `README.tslist`
* `RRTM_DATA`
* `RRTM_DATA_DBL`
* `RRTMG_LW_DATA`
* `RRTMG_LW_DATA_DBL`
* `RRTMG_SW_DATA`
* `RRTMG_SW_DATA_DBL`
* `SOILPARM.TBL`
* `SOILPARM.TBL_Kishne_2017`
* `STOCHPERT.TBL`
* `target_grid_sul_br_0125.txt`
* `tr49t67`
* `tr49t85`
* `tr67t85`
* `URBPARM.TBL`
* `URBPARM_LCZ.TBL`
* `URBPARM_UZE.TBL`
* `urls.txt`
* `Vtable.ICONm`
* `Vtable.ICONp`
* `Vtable.ECMWF`
* `VEGPARM.TBL`
* `wind-turbine-1.tbl`
* `termvels.asc`

---

#### **2. Scripts e Componentes Principais**

* **`download_era5_range.py`**: Script Python para baixar dados de reanálise do ERA5. Ele verifica se os arquivos já existem antes de iniciar o download, evitando transferências desnecessárias.
* **`rodar_wrf_era5.sh`**: O script mestre que orquestra o fluxo de trabalho do WRF. Ele gerencia o download de dados, a execução do WPS (com checagem de arquivos de saída) e a execução do `real.exe` e `wrf.exe`.
* **`rodar_wps_wrf.sh`**: Uma versão mais simples do script de automação, sem a verificação de arquivos. O uso do `rodar_wrf_era5.sh` é recomendado por ser mais robusto.
* **`plotar_rodadas_diaria_parallel.sh`**: Script para pós-processamento e plotagem. Utiliza `GNU parallel` para gerar gráficos das variáveis do modelo de forma otimizada.
* **`orquestrador_web.py`**: Script Python que gera a interface web de visualização. Ele cria um calendário de previsões e um visualizador interativo para cada rodada, com descrições detalhadas das variáveis meteorológicas.
* **`.gitignore`**: Lista os arquivos e diretórios que o Git deve ignorar, como dados de simulação (`.grib`, `.nc`) e pastas de execução (`run`, `gribdata`), mantendo o repositório leve.

---
Para mais detalhes sobre a instalação do WRF em Linux, assista a este vídeo de tutorial [WRF INSTALLATION LATEST (2025) | BEST AND EASY WRF SET-UP | WRF Model Tutorial](https://www.youtube.com/watch?v=B03LXSczVus).
http://googleusercontent.com/youtube_content/6
