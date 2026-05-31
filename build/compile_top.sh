# Директория скрипта.

curdir=$(pwd)

# Директория артефактов симулятора.

mkdir -p ${curdir}/work/top

# Компиляция исходных файлов в Xcelium выполняется с помощью команды
# 'xrun -compile'. Исходные файлы передаются этой команде.

# Аргумент '-xmlibdirpath' используется для указания пути к директории
# артефактов симулятора.

# Аргумент '-l' указывает путь к лог-файлу компиляции.

xrun -compile -64bit ${curdir}/../pkg/cache_pkg.sv ${curdir}/../rtl/single_port_ram.sv ${curdir}/../rtl/cache_top.sv \
    ${curdir}/../rtl/credit_cnt.sv ${curdir}/../rtl/cnt.sv ${curdir}/../rtl/dual_port_ram.sv ${curdir}/../rtl/fifo.sv ${curdir}/../rtl/show_ahead_fifo.sv \
    ${curdir}/../rtl/onehot_decoder.sv ${curdir}/../rtl/plru_calc.sv  ${curdir}/../rtl/plru_refill.sv ${curdir}/../rtl/plru_wrapper.sv ${curdir}/../rtl/cache_fsm.sv \
    ${curdir}/../rtl/hit_miss_detect.sv ${curdir}/../rtl/mshr.sv ${curdir}/../rtl/cache_data_read.sv ${curdir}/../tb/tb_configure_cache.sv \
    -xmlibdirpath ${curdir}/work/top -l ${curdir}/compile.log