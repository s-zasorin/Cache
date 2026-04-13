# Директория скрипта.

curdir=$(pwd)

# Директория артефактов симулятора.

mkdir -p ${curdir}/work

# Компиляция исходных файлов в Xcelium выполняется с помощью команды
# 'xrun -compile'. Исходные файлы передаются этой команде.

# Аргумент '-xmlibdirpath' используется для указания пути к директории
# артефактов симулятора.

# Аргумент '-l' указывает путь к лог-файлу компиляции.

xrun -compile -64bit ${curdir}/../pkg/cache_pkg.sv ${curdir}/../rtl/configure_cache.sv ${curdir}/../rtl/single_port_ram.sv ${curdir}/../tb/tb_configure_cache.sv \
    ${curdir}/../rtl/bin_decoder.sv ${curdir}/../rtl/onehot_decoder.sv ${curdir}/../rtl/plru_calc.sv  ${curdir}/../rtl/plru_refill.sv\
    -xmlibdirpath ${curdir}/work -l ${curdir}/compile.log