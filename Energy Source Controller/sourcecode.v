module home_energy_source_controller ( input clk ,
input reset , 
input ac_on ,
input fan_on ,
input wm_on ,
input bulb_on ,
input fridge_on , 
input day_flag , // 1 for day and 0 for night
input battery_status, 
output solar_mode ,
output battery_mode,
output grid_mode
    
);

wire [15:0] total_load ;
wire [15:0] solar_generation ;
wire [15:0] energy_consumption ;
wire [15:0] cost;
load_calculator load_calc (
    .ac_on(ac_on),
    .fan_on(fan_on),
    .wm_on(wm_on),
    .bulb_on(bulb_on),
    .fridge_on(fridge_on),
    .total_load(total_load)
);
solar_generation_calculator solar_calc (
    .day_flag(day_flag),
    .solar_generation(solar_generation)
);
energy_consumption_calculator energy_calc (
    .total_load(total_load),
    .energy_consumption(energy_consumption)
);
cost_calculator cost_calc (
    .energy_consumption(energy_consumption),
    .cost(cost)
);
energy_source_decision_controller decision_ctrl (
    .solar_generation(solar_generation),
    .battery_status(battery_status),
    .cost(cost),
    .solar_mode(solar_mode),
    .battery_mode(battery_mode),
    .grid_mode(grid_mode)
);




    
endmodule
