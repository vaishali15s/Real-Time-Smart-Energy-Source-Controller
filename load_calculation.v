//============================================================================
// LOAD CALCULATOR (APPLIANCE POWER AGGREGATOR)\n//============================================================================
// Calculates total household load by summing individual appliance demands.
// Each appliance contributes its power consumption only when ON.
//
// MODELED APPLIANCES:\n//   - AC (Air Conditioner):  1500 W (high consumption)\n//   - Fan:                     100 W\n//   - Washing Machine:         800 W (high consumption)\n//   - Bulb (Lights):           100 W\n//   - Fridge:                  200 W (continuous)\n//
// TOTAL RANGE: 0 - 2700 W max (all appliances on)\n//
// OUTPUT: total_load = sum of all (appliance power IF on_signal)\n//============================================================================

module load_calculator (
    input ac_on,
    input fan_on,
    input wm_on,         // Washing machine on/off
    input bulb_on,
    input fridge_on,
    output reg [15:0] total_load  // Total load in watts
);

    //====================================================
    // APPLIANCE LOAD AGGREGATION\n    //====================================================
    // Combinational logic: sum all active appliances
    // No clock or state required
    //====================================================
    always @(*) begin
        total_load = 16'd0;  // Initialize to zero

        // Add each appliance's power if its on_signal is active
        if (ac_on)      total_load = total_load + 16'd1500;  // A/C: high power
        if (fan_on)     total_load = total_load + 16'd100;   // Fan: medium
        if (wm_on)      total_load = total_load + 16'd800;   // Washer: high power
        if (bulb_on)    total_load = total_load + 16'd100;   // Lights: low
        if (fridge_on)  total_load = total_load + 16'd200;   // Fridge: medium
    end

endmodule