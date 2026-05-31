
# XM-Sim Command File
# TOOL:	xmsim(64)	22.03-s001
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 6925
set assert_reporting_mode 0
set vcd_compact_mode 0
alias . run
alias quit exit
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_configure_cache.DUT.aresetn_i tb_configure_cache.DUT.clk_i tb_configure_cache.DUT.cpu_addr_i tb_configure_cache.DUT.cpu_data_o tb_configure_cache.DUT.cpu_ready_o tb_configure_cache.DUT.cpu_req_id_i tb_configure_cache.DUT.cpu_req_id_o tb_configure_cache.DUT.cpu_valid_i tb_configure_cache.DUT.cpu_valid_o tb_configure_cache.DUT.credit_cnt tb_configure_cache.DUT.credit_decr tb_configure_cache.DUT.credit_incr tb_configure_cache.DUT.dr_fifo_m_data tb_configure_cache.DUT.dr_fifo_m_ready tb_configure_cache.DUT.dr_fifo_m_valid tb_configure_cache.DUT.dr_fifo_s_data tb_configure_cache.DUT.dr_fifo_s_ready tb_configure_cache.DUT.dr_fifo_s_valid tb_configure_cache.DUT.dr_ram_data_read tb_configure_cache.DUT.dr_ready tb_configure_cache.DUT.dr_valid tb_configure_cache.DUT.fsm_write_back tb_configure_cache.DUT.hmd_addr tb_configure_cache.DUT.hmd_fifo_m_data tb_configure_cache.DUT.hmd_fifo_m_ready tb_configure_cache.DUT.hmd_fifo_m_valid tb_configure_cache.DUT.hmd_fifo_s_data tb_configure_cache.DUT.hmd_fifo_s_ready tb_configure_cache.DUT.hmd_fifo_s_valid tb_configure_cache.DUT.hmd_hit tb_configure_cache.DUT.hmd_id tb_configure_cache.DUT.hmd_miss tb_configure_cache.DUT.hmd_set tb_configure_cache.DUT.hmd_valid_in tb_configure_cache.DUT.hmd_valid_out tb_configure_cache.DUT.hmd_we_dr_out tb_configure_cache.DUT.init tb_configure_cache.DUT.init_cnt_ff tb_configure_cache.DUT.mem_ack_i tb_configure_cache.DUT.mem_addr_o tb_configure_cache.DUT.mem_data_i tb_configure_cache.DUT.mem_handshake tb_configure_cache.DUT.mem_id_i tb_configure_cache.DUT.mem_id_o tb_configure_cache.DUT.mem_req_o tb_configure_cache.DUT.mem_valid_i tb_configure_cache.DUT.plru_tree tb_configure_cache.DUT.work

simvision -input /home/Stepan/cache/build/.simvision/30163_Stepan__autosave.tcl.svcf
