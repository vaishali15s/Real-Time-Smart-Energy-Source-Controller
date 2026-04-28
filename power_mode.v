//============================================================================
// LEGACY ENERGY SOURCE CONTROLLER (Simplified FSM)\n//============================================================================
// Simplified predecessor of energy_fsm implementing basic source selection.
// This module demonstrates the core logic before advanced features like:
//   - Peak-demand prediction
//   - PWM charging control
//   - Hysteresis (state debouncing)
//   - IDLE state
//   - Fault codes
//
// LOGIC:\n//   DAYTIME:\n//     1. If solar >= load: Use SOLAR (preferred, free energy)\n//     2. Else if SOC > threshold: Use BATTERY (preserve for night)\n//     3. Else: Use GRID (fallback)\n//\n//   NIGHTTIME:\n//     1. If SOC > threshold: Use BATTERY (no solar available)\n//     2. Else: Use GRID (battery depleted)\n//\n// INPUTS:
//   total_load      : Current load demand (watts)
//   solar_generation: Solar output (watts)\n//   battery_soc     : Battery charge level (0-100%)\n//   day_flag        : 1 = daytime, 0 = nighttime
//
// OUTPUTS:
//   solar_mode      : Active when using solar\n//   battery_mode    : Active when using battery
//   grid_mode       : Active when using grid
//============================================================================

module energy_source_controller (
    input [15:0] total_load,
    input [15:0] solar_generation,
    input [6:0] battery_soc,
    input day_flag,                // 1 = day, 0 = night

    output reg solar_mode,         // Active when solar is source
    output reg battery_mode,       // Active when battery is source
    output reg grid_mode           // Active when grid is source
);

    //====================================================
    // SOC THRESHOLD
    //====================================================
    // Minimum battery state-of-charge for discharge:
    // If SOC falls below this, switch to grid to prevent over-discharge
    parameter SOC_LOW = 7'd20;  // 20% minimum safe SOC

    //====================================================
    // SOURCE SELECTION LOGIC (Combinational)
    //====================================================
    // Selects energy source based on time-of-day and resource availability
    //====================================================
    always @(*) begin
        // Initialize all sources to inactive
        solar_mode = 1'b0;
        battery_mode = 1'b0;
        grid_mode = 1'b0;

        //================================================
        // DAYTIME LOGIC (Solar available)\n        //================================================
        // Priority: Solar > Battery > Grid
        if (day_flag == 1'b1) begin
            if (solar_generation >= total_load)
                //--- Case 1: Solar sufficient for full load ---
                solar_mode = 1'b1;  // Use solar (renewable, free)
            else if (battery_soc > SOC_LOW)
                //--- Case 2: Solar insufficient but battery available ---
                battery_mode = 1'b1;  // Use battery to preserve renewable
            else
                //--- Case 3: Solar insufficient and battery low ---
                grid_mode = 1'b1;  // Fallback to grid (safety)
        end

        //================================================
        // NIGHTTIME LOGIC (No solar available)\n        //================================================
        // Priority: Battery > Grid
        else begin
            if (battery_soc > SOC_LOW)
                //--- Case 1: Battery above minimum threshold ---
                battery_mode = 1'b1;  // Use battery (most efficient at night)
            else
                //--- Case 2: Battery below threshold ---
                grid_mode = 1'b1;  // Use grid (battery protection)
        end

    end

endmodule