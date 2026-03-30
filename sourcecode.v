module home_energy_source_controller (
    input clk,
    input reset, 
    input ac_on,
    input fan_on,
    input wm_on,
    input bulb_on,
    input fridge_on, 
    input day_flag,
    input [6:0] battery_soc,

    output solar_mode,
    output battery_mode,
    output grid_mode
);

    wire [15:0] total_load;
    wire [15:0] solar_generation;
    wire [15:0] energy_consumption;
    wire [15:0] cost;

    // Load calculation
    load_calculator load_calc (
        .ac_on(ac_on),
        .fan_on(fan_on),
        .wm_on(wm_on),
        .bulb_on(bulb_on),
        .fridge_on(fridge_on),
        .total_load(total_load)
    );

    // Solar generation
    solar_generation_calculator solar_calc (
        .day_flag(day_flag),
        .solar_generation(solar_generation)
    );

    // Energy + Cost
    energy_consumption_calculator energy_calc (
        .total_load(total_load),
        .energy_consumption(energy_consumption),
        .cost(cost)
    );

    // FSM Controller
    energy_fsm decision_ctrl (
        .clk(clk),
        .reset(reset),
        .load(total_load),
        .solar(solar_generation),
        .day_flag(day_flag),
        .battery_soc(battery_soc),
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode)
    );

endmodule