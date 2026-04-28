//============================================================================
// SMART LOAD MANAGER (PRIORITY-BASED LOAD SHEDDING)
//============================================================================
// Implements intelligent load prioritization to manage total power consumption.
// When available power is limited (e.g., low battery, low solar), this module
// selectively enables only the highest-priority loads that fit within the
// available power budget.
//
// PRIORITY ORDER (Highest to Lowest):
//   1. Fridge (200 W)     - Essential, continuous operation
//   2. Fan (100 W)        - Comfort, low power
//   3. Bulb (100 W)       - Essential for visibility
//   4. Washing Machine (800 W) - Non-essential, deferrable
//   5. Air Conditioner (1500 W) - Least essential, high power
//
// ALGORITHM:\n//   For each appliance in priority order:
//     - If (current_load + appliance_load) <= available_power:
//         Enable appliance and add to load
//     - Else:
//         Disable appliance (insufficient power budget)
//
// INPUTS:
//   ac_on, fan_on, wm_on, bulb_on, fridge_on : User requests (on/off)
//   available_power                            : Power budget in watts
//
// OUTPUTS:
//   ac_supply, fan_supply, wm_supply, bulb_supply, fridge_supply : Enable signals
//   final_load : Actual load (sum of enabled appliances <= available_power)
//
// USE CASE:\n//   Battery running low -> reduce available_power -> module sheds non-essential loads
//   Solar peak at noon -> increase available_power -> module enables more loads
//============================================================================

module smart_load_manager(

    // Appliance on/off requests from user
    input  ac_on,           // Air conditioner request
    input  fridge_on,       // Refrigerator request
    input  wm_on,           // Washing machine request
    input  fan_on,          // Fan request
    input  bulb_on,         // Light bulb request

    // Available power budget (from source selection)
    input  [15:0] available_power,  // Maximum power budget (watts)

    // Per-appliance supply enable outputs
    output reg ac_supply,
    output reg fridge_supply,
    output reg wm_supply,
    output reg fan_supply,
    output reg bulb_supply,

    // Total actual load (sum of enabled appliances)
    output reg [15:0] final_load

);

    //====================================================
    // PRIORITY-BASED LOAD MANAGEMENT (Combinational)
    //====================================================
    // Implements greedy algorithm: enable loads in priority order until
    // budget exhausted. Lower-priority loads may be shed if power limited.
    //====================================================
    always @(*) begin

        // Initialize: all supplies off, zero load
        ac_supply     = 1'b0;
        fridge_supply = 1'b0;
        wm_supply     = 1'b0;
        fan_supply    = 1'b0;
        bulb_supply   = 1'b0;

        final_load = 16'd0;

        //================================================\n        // PRIORITY 1: FRIDGE (Essential, continuous)\n        //================================================
        // Fridge is highest priority: must run for food preservation
        if (fridge_on) begin
            if (final_load + 16'd200 <= available_power) begin
                fridge_supply = 1'b1;      // Enable fridge supply
                final_load = final_load + 16'd200;  // Add 200W to load
            end
        end

        //================================================
        // PRIORITY 2: FAN (Comfort, low power)\n        //================================================
        // Fan is next priority: uses little power, improves comfort
        if (fan_on) begin
            if (final_load + 16'd100 <= available_power) begin
                fan_supply = 1'b1;         // Enable fan supply
                final_load = final_load + 16'd100;  // Add 100W to load
            end
        end

        //================================================
        // PRIORITY 3: BULB (Essential for visibility)\n        //================================================
        // Lights are important for safety and visibility
        if (bulb_on) begin
            if (final_load + 16'd100 <= available_power) begin
                bulb_supply = 1'b1;        // Enable bulb supply
                final_load = final_load + 16'd100;  // Add 100W to load
            end
        end

        //================================================
        // PRIORITY 4: WASHING MACHINE (Deferrable)\n        //================================================
        // Washing machine is non-essential and deferrable
        if (wm_on) begin
            if (final_load + 16'd800 <= available_power) begin
                wm_supply = 1'b1;          // Enable washer supply
                final_load = final_load + 16'd800;  // Add 800W to load
            end
        end

        //================================================
        // PRIORITY 5: AIR CONDITIONER (Lowest priority)\n        //================================================
        // A/C is least essential; only enabled if plenty of power available
        if (ac_on) begin
            if (final_load + 16'd1500 <= available_power) begin
                ac_supply = 1'b1;          // Enable A/C supply
                final_load = final_load + 16'd1500;  // Add 1500W to load
            end
        end

    end  // end of always

endmodule