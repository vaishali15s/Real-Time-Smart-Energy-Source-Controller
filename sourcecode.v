module home_energy_source_controller (
    input clk,
    input reset, 
    input ac_on,
    input fan_on,
    input wm_on,
    input bulb_on,
    input fridge_on, 
    input day_flag,
    input [15:0] solar_generation,

    output solar_mode,
    output battery_mode,
    output grid_mode,
    output ac_supply,
    output fridge_supply,
    output wm_supply,
    output fan_supply,
    output bulb_supply,
    output [15:0] final_load
);

    wire [6:0] battery_soc;
    wire [15:0] total_load;
    wire [15:0] energy_consumption;
    wire [15:0] cost;
    wire [15:0] available_power;

    wire solar_mode_i;
    wire battery_mode_i;
    wire grid_mode_i;

    // Load calculation
    load_calculator load_calc (
        .ac_on(ac_on),
        .fan_on(fan_on),
        .wm_on(wm_on),
        .bulb_on(bulb_on),
        .fridge_on(fridge_on),
        .total_load(total_load)
    );
    battery_soc_controller soc_ctrl(
        .clk(clk),
        .reset(reset),
        .load(total_load),
        .solar(solar_generation),
        .battery_mode(battery_mode),
        .battery_soc(battery_soc)
);

    assign available_power = solar_mode_i ? solar_generation :
                             battery_mode_i ? (battery_soc * 16'd100) :
                             16'hFFFF;

    smart_load_manager load_manager (
        .ac_on(ac_on),
        .fridge_on(fridge_on),
        .wm_on(wm_on),
        .fan_on(fan_on),
        .bulb_on(bulb_on),
        .available_power(available_power),
        .ac_supply(ac_supply),
        .fridge_supply(fridge_supply),
        .wm_supply(wm_supply),
        .fan_supply(fan_supply),
        .bulb_supply(bulb_supply),
        .final_load(final_load)
    );


    // Energy + Cost
    energy_consumption_calculator energy_calc (
        .total_load(final_load),
        .energy_consumption(energy_consumption),
        .cost(cost)
    );

    // Energy Source Controller
    energy_source_controller decision_ctrl (
        .total_load(total_load),
        .solar_generation(solar_generation),
        .day_flag(day_flag),
        .battery_soc(battery_soc),
        .solar_mode(solar_mode_i),
        .battery_mode(battery_mode_i),
        .grid_mode(grid_mode_i)
    );

    assign solar_mode = solar_mode_i;
    assign battery_mode = battery_mode_i;
    assign grid_mode = grid_mode_i;

endmodule