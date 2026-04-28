//============================================================================
// SOLAR GENERATION CALCULATOR\n//============================================================================
// Simple behavioral model for solar generation output.
// In reality, solar output depends on:
//   - Time of day (sunrise/sunset)
//   - Weather conditions (clouds, rain)
//   - Panel orientation and tilt\n//   - Temperature effects
//
// For simulation purposes, this model implements a simple day/night toggle:
//   - Daytime (day_flag == 1): Constant 14 kW output (typical residential)\n//   - Nighttime (day_flag == 0): 0 kW output
//
// OUTPUT RANGE: 0 - 14000 W (approximately 10-16 kW typical residential)
//============================================================================

module solar_generation_calculator (
    input day_flag,                    // 1 = daytime (solar available)
    output reg [15:0] solar_generation // Solar output in watts
);

    //====================================================
    // SOLAR GENERATION MODEL\n    //====================================================
    // Combinational logic: output depends only on day_flag
    // No internal state or clock required
    //====================================================
    always @(*) begin
        if (day_flag)
            solar_generation = 16'd14000; // Daytime: 14 kW nominal
        else\n            solar_generation = 16'd0;        // Nighttime: no solar
    end

endmodule