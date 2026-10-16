# SPDX-License-Identifier: MIT
# Source after synthesis; call for each retained mailbox hierarchy instance.
# Budgets are the FASTEST operating clock periods in ns, not clock ratios.
proc cdc_mailbox_regs {instance pattern} {
    set cells [get_cells -hier -quiet -filter [format {NAME =~ "%s/%s"} $instance $pattern]]
    if {[llength $cells] == 0} {error "CDC mailbox: missing $instance/$pattern"}
    return $cells
}
proc cdc_mailbox_first {instance name} {
    set cells [get_cells -hier -quiet -filter [format {NAME == "%s/%s_reg[0]"} $instance $name]]
    if {[llength $cells] != 1} {error "CDC mailbox: expected one first-stage $instance/$name"}
    return [get_pins -of_objects $cells -filter {REF_PIN_NAME == D}]
}
proc constrain_cdc_mailbox {instance src_period_ns dst_period_ns} {
    if {$src_period_ns <= 0 || $dst_period_ns <= 0} {error "CDC mailbox periods must be positive"}
    set req [get_pins -of_objects [cdc_mailbox_regs $instance req_toggle_reg] -filter {REF_PIN_NAME == Q}]
    set ack [get_pins -of_objects [cdc_mailbox_regs $instance ack_toggle_reg] -filter {REF_PIN_NAME == Q}]
    set_false_path -from $req -to [cdc_mailbox_first $instance req_sync]
    set_false_path -from $ack -to [cdc_mailbox_first $instance ack_sync]
    set request_from [get_pins -of_objects [cdc_mailbox_regs $instance src_payload_reg*] -filter {REF_PIN_NAME == Q}]
    set request_to [get_pins -of_objects [cdc_mailbox_regs $instance dst_data_reg*] -filter {REF_PIN_NAME == D}]
    set response_from [get_pins -of_objects [cdc_mailbox_regs $instance dst_response_reg*] -filter {REF_PIN_NAME == Q}]
    set response_to [get_pins -of_objects [cdc_mailbox_regs $instance src_rsp_data_reg*] -filter {REF_PIN_NAME == D}]
    set_max_delay -datapath_only $dst_period_ns -from $request_from -to $request_to
    set_bus_skew $dst_period_ns -from $request_from -to $request_to
    set_max_delay -datapath_only $src_period_ns -from $response_from -to $response_to
    set_bus_skew $src_period_ns -from $response_from -to $response_to
}
