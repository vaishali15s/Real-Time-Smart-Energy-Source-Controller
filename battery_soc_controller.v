//============================================================================
// BATTERY STATE-OF-CHARGE (SOC) CONTROLLER
//============================================================================
// This module manages battery state-of-charge (SOC) tracking.
// It simulates charging when surplus solar exists, discharging when battery
// supplies load, and includes FSM-requested pre-charging for peak demand.
//
// FEATURES:
//   - Charge when: (1) surplus solar (solar > load), OR (2) precharge_request
//   - Discharge based on load magnitude during battery_mode
//   - Gradual idle drain when no load
//   - Gated by allow_charge to prevent charging during faults
//
// INPUTS:
//   clk                : Clock signal
//   reset              : Asynchronous reset
//   load               : Current load demand (watts)
//   solar              : Solar generation (watts)
//   battery_mode       : Assert when battery is active source
//   allow_charge       : Gate signal (allows charging only when true)
//   precharge_request  : FSM request to pre-charge for upcoming peak
//
// OUTPUTS:
//   battery_soc        : Battery state-of-charge (0-100%)
//
// OPERATION:
//   - Charging (SOC incrementing):
//     Occurs when BOTH conditions met:
//       1. allow_charge == 1 (no fault)
//       2. EITHER precharge_request==1 OR solar > load
//   - Discharging (SOC decrementing):
//     Occurs when battery_mode==1 and there is load
//   - Idle drain: Slow decay when no active load/discharge
//============================================================================

module battery_soc_controller (
    input clk,
    input reset,
    input [15:0] load,             // Current load demand (W)
    input [15:0] solar,            // Current solar generation (W)
    input battery_mode,            // Battery is active source
    input allow_charge,            // Enable charging (gate for faults)
    input precharge_request,       // FSM request to pre-charge

    output reg [6:0] battery_soc   // Battery SOC: 0-100%
);

    //====================================================
    // CHARGING & DISCHARGING PARAMETERS
    //====================================================
    parameter STEP_CHARGE = 2;              // SOC increment per clock cycle (charging)
    parameter STEP_DISCHARGE = 1;           // SOC decrement per clock cycle (discharging)
    parameter NO_LOAD_DRAIN_PERIOD = 8;   // Idle drain every N cycles without load

    reg [3:0] no_load_ctr;  // Counter for idle drain triggering

    //====================================================
    // SOC STATE MACHINE
    //====================================================
    // Implements three operating modes: Charge, Discharge, Idle
    // Updated on each clock rising edge when not in reset
    //====================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize at 50% SOC (mid-range operating point)
            battery_soc <= 7'd50;
            no_load_ctr <= 4'd0;
        end
        else begin

            //========================================================
            // CHARGING CONDITION
            //========================================================
            // Charge battery when BOTH:
            //   1. allow_charge == 1 (no fault condition)
            //   2. EITHER:
            //      a. precharge_request == 1 (FSM anticipatory pre-charge), OR
            //      b. solar > load (surplus solar energy available)
            // Rate: +STEP_CHARGE per cycle (default +2 % per cycle)
            // Cap: Battery SOC maxes out at 100%
            //========================================================
            if (allow_charge && (precharge_request || (solar > load))) begin
                // Increment SOC, but cap at 100%
                if (battery_soc >= (7'd100 - STEP_CHARGE))
                    battery_soc <= 7'd100;  // Prevent overflow
                else
                    battery_soc <= battery_soc + STEP_CHARGE;  // Charge
                no_load_ctr <= 4'd0;  // Reset idle counter (active charging)
            end

            //========================================================
            // DISCHARGING CONDITION
            //========================================================
            // Discharge battery when:
            //   1. battery_mode == 1 (battery is active source), AND
            //   2. There is load demand (load > 0)
            // Rate: -STEP_DISCHARGE per cycle (default -1 % per cycle)
            // Special case: if load == 0, apply gradual idle drain
            //========================================================
            else if (battery_mode) begin
                if (load == 16'd0) begin
                    // No load, but battery_mode active (idle condition)
                    // Apply slow background drain every NO_LOAD_DRAIN_PERIOD cycles
                    if (no_load_ctr >= (NO_LOAD_DRAIN_PERIOD - 1)) begin
                        no_load_ctr <= 4'd0;
                        // Decrement once per drain period
                        if (battery_soc > 0)
                            battery_soc <= battery_soc - STEP_DISCHARGE;
                        else
                            battery_soc <= 7'd0;  // Floor at 0%
                    end
                    else begin
                        // Increment idle counter (not yet time for drain)
                        no_load_ctr <= no_load_ctr + 1'b1;
                        battery_soc <= battery_soc;  // Hold SOC
                    end
                end
                else begin
                    // Load present: discharge normally
                    no_load_ctr <= 4'd0;  // Reset idle counter
                    if (battery_soc > 0)
                        battery_soc <= battery_soc - STEP_DISCHARGE;  // Discharge
                    else
                        battery_soc <= 7'd0;  // Floor at 0%
                end
            end

            //========================================================
            // IDLE CONDITION
            //========================================================
            // Neither charging nor discharging:
            //   - battery_mode == 0 (battery not active source)
            //   - No charging condition met (solar low, no precharge)
            // Action: Hold SOC and reset idle counter
            //========================================================
            else begin
                battery_soc <= battery_soc;  // Maintain SOC
                no_load_ctr <= 4'd0;         // Reset idle counter
            end

        end  // end of else (not reset)
    end  // end of always

endmodule