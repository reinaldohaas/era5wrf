import cdsapi
import os
import sys
from datetime import datetime, timedelta

# =============================================================================
#  Script para baixar dados do ERA5 para um intervalo de tempo.
#
#  Funcionalidade Adicionada:
#    - Verifica se os arquivos de dados já existem antes de baixar.
#
#  Argumentos:
#    1: Data de Início (yyyymmddhh)
#    2: Data de Fim (yyyymmddhh)
#    3: Diretório de Saída
# =============================================================================

def download_era5_data(start_str, end_str, output_dir):
    """
    Baixa dados de níveis de pressão e superfície do ERA5 para um intervalo de datas.
    Pula o download se os arquivos já existirem.
    """
    print("Verificando a existência dos arquivos de dados ERA5...")
    
    # Define os nomes dos arquivos de saída esperados
    pl_filename = os.path.join(output_dir, f'era5_pl_{start_str}_{end_str}.grib')
    sfc_filename = os.path.join(output_dir, f'era5_sfc_{start_str}_{end_str}.grib')

    # --- INÍCIO DA MODIFICAÇÃO ---
    # Verifica se ambos os arquivos já existem
    if os.path.exists(pl_filename) and os.path.exists(sfc_filename):
        print(f"   - Arquivos já encontrados em {output_dir}. Download ignorado.")
        return # Sai da função e permite que o script principal continue
    # --- FIM DA MODIFICAÇÃO ---

    print("   - Arquivos não encontrados. Iniciando o download no CDS.")
    
    try:
        start_date = datetime.strptime(start_str, '%Y%m%d%H')
        end_date = datetime.strptime(end_str, '%Y%m%d%H')
    except ValueError:
        print("Erro: Formato de data inválido. Use yyyymmddhh.")
        sys.exit(1)

    # Cria o diretório se não existir
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Diretório criado: {output_dir}")

    # Define a área de interesse [Norte, Oeste, Sul, Leste]
    area = [-20, -65, -35, -40] # Exemplo para o Sul do Brasil

    # Calcula o número total de horas como um inteiro
    total_hours = int((end_date - start_date).total_seconds() / 3600)
    date_list = [start_date + timedelta(hours=x) for x in range(0, total_hours + 1)]
    
    days = sorted(list(set([d.strftime('%d') for d in date_list])))
    times = sorted(list(set([d.strftime('%H:00') for d in date_list])))
    year = start_date.strftime('%Y')
    month = start_date.strftime('%m')
    
    c = cdsapi.Client()

    # --- Requisição para Níveis de Pressão ---
    print(f"Baixando dados de Níveis de Pressão para {start_str} a {end_str}...")
    c.retrieve(
        'reanalysis-era5-pressure-levels',
        {
            'product_type': 'reanalysis', 'format': 'grib',
            'variable': ['geopotential', 'relative_humidity', 'temperature', 'u_component_of_wind', 'v_component_of_wind'],
              'pressure_level': [ '1', '2', '3', '5', '7', '10', '20', '30', '50', '70', '100', '125', '150', '175', '200', '225', '250', '300', '350', '400', '450', '500', '550', '600', '650', '700', '750', '775', '800', '825', '850', '875', '900', '925', '950', '975', '1000'],
            'year': year, 'month': month, 'day': days, 'time': times, 'area': area,
        },
        pl_filename
    )

    # --- Requisição para Nível de Superfície ---
    print(f"Baixando dados de Superfície para {start_str} a {end_str}...")
    c.retrieve(
        'reanalysis-era5-single-levels',
        {
            'product_type': 'reanalysis', 'format': 'grib',
            'variable':[
            '10m_u_component_of_wind', '10m_v_component_of_wind', '2m_dewpoint_temperature',
            '2m_temperature', 'land_sea_mask', 'mean_sea_level_pressure',
            'sea_ice_cover', 'sea_surface_temperature', 'skin_temperature', 'snow_depth',
            'soil_temperature_level_1', 'soil_temperature_level_2', 'soil_temperature_level_3',
            'soil_temperature_level_4', 'surface_pressure', 'volumetric_soil_water_layer_1',
            'volumetric_soil_water_layer_2', 'volumetric_soil_water_layer_3', 'volumetric_soil_water_layer_4'
            ],
            'year': year, 'month': month, 'day': days, 'time': times, 'area': area,
        },
        sfc_filename
    )
    print(f"Download concluído! Arquivos salvos em {output_dir}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Uso: python download_era5_range.py <data_inicio_yyyymmddhh> <data_fim_yyyymmddhh> <diretorio_saida>")
        sys.exit(1)
    
    download_era5_data(sys.argv[1], sys.argv[2], sys.argv[3])
