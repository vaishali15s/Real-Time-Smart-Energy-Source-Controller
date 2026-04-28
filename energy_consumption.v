//============================================================================
// ENERGY CONSUMPTION CALCULATOR
//============================================================================
// Simple utility module to track energy consumption and calculate costs.
// This module mirrors the load at its output and computes electricity cost
// based on a fixed rate (₹8 per unit as example).
//
// FUNCTION:\n//   - Pass-through load to energy_consumption output
//   - Multiply load by fixed rate to get cost
//
// INPUTS:
//   total_load          : Current power consumption (watts)
//
// OUTPUTS:
//   energy_consumption : Energy used (watts - direct copy of load)
//   cost                : Cost in rupees (load * rate)
//
// OPERATION:
//   Combinational logic only (no state, no clock needed)
//   Cost = total_load * 8  (₹8 per kWh equivalent)
//============================================================================

module energy_consumption_calculator (
    input [15:0] total_load,           // Current load (watts)
    output reg [15:0] energy_consumption, // Energy consumption (watts)
    output reg [15:0] cost             // Cost in rupees
);

    //====================================================
    // ENERGY & COST CALCULATION (Combinational)
    //====================================================
    // Direct pass-through of load to energy_consumption
    // Cost is fixed-rate calculation: load * 8
    //====================================================
    always @(*) begin
        energy_consumption = total_load;  // Pass-through consumption
        cost = total_load * 8;            // Fixed rate: ₹8 per unit
    end

endmodule