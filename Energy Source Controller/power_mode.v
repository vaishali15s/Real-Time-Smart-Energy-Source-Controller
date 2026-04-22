module energy_source_controller (
    input [15:0] total_load,
    input [15:0] solar_generation,
    input [6:0] battery_soc,
    input day_flag,          // 1 = day, 0 = night

    output reg solar_mode,  
    output reg battery_mode,
    output reg grid_mode
);

parameter SOC_LOW = 7'd20;

always @(*) 
begin
    // default values
    solar_mode = 0;
    battery_mode = 0;
    grid_mode = 0;

    // DAYTIME LOGIC
    if (day_flag == 1) 
    begin
        if (solar_generation >= total_load)
            solar_mode = 1;        // solar sufficient
        else if (battery_soc > SOC_LOW)
            battery_mode = 1;      // use battery if available
        else
            grid_mode = 1;         // fallback to grid
    end
    
    // NIGHT LOGIC
    else 
    begin
        if (battery_soc > SOC_LOW)
            battery_mode = 1;      // battery at night if available
        else
            grid_mode = 1;         // grid if battery low
    end

end

endmodule