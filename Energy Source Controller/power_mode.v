module energy_source_controller (
    input [15:0] total_load,
    input [15:0] solar_generation,  
    input battery_status,
    input [15:0] day_flag, // 1 for day and 0 for night
    output reg solar_mode,  
    output reg battery_mode,
    output reg grid_mode
);
always @(*) begin
    solar_mode = 0;
    battery_mode = 0;   
    grid_mode = 0;
    if (solar_generation >= total_load) begin
        solar_mode = 1; // Use solar power
    end else if (battery_status) begin
        battery_mode = 1; // Use battery power
    end else begin
        grid_mode = 1; // Use grid power
    end
    else begin
        grid_mode = 1; // Use grid power at night or when solar generation is insufficient
    end 
    else if (day_flag == 0) begin
        grid_mode = 1; // Use grid power at night
    end 

    
end
    
endmodule