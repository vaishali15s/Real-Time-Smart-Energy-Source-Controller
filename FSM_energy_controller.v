//============================================================================
// ENERGY SOURCE FINITE STATE MACHINE (FSM) CONTROLLER
//============================================================================
// This module implements the core logic for selecting between multiple energy
// sources (Solar, Battery, Grid) based on availability, cost, and demand.
// Features: Peak-demand prediction, PWM-controlled charging, fault detection,
// tariff-aware selection, and state hysteresis for stable operation.
//============================================================================

module energy_fsm (
    input clk,
    input reset,

    // Energy source inputs
    input [15:0] load,        // Current load demand in watts
    input [15:0] solar,       // Current solar generation in watts
    input [6:0] battery_soc,  // Battery state-of-charge (0-100%)

    input [1:0] tariff_slot,  // Time-of-use tariff: 00=Night, 01=Day, 10=Peak

    // Fault input signals (active high)
    input battery_overtemp,   // Battery temperature exceeded safe limit
    input solar_fault,        // Solar system malfunction detected
    input overload,           // Load exceeds safe operating limit
    input grid_fault,         // Grid power unavailable

    // Primary mode outputs (exactly one active at a time)
    output reg solar_mode,    // Active = supplying from solar
    output reg battery_mode,  // Active = supplying from battery
    output reg grid_mode,     // Active = supplying from grid
    output reg fault_mode,    // Active = fault condition detected
    
    output reg [2:0] fault_code,       // Fault diagnostic code
    output reg precharge_request,      // Request to pre-charge battery ahead of peak
    output reg pwm_out,                // PWM control signal for charging
    output reg [7:0] pwm_duty,         // PWM duty cycle (0-255, where 128 = 50%)
    output reg idle_mode               // Active = no load, no source active
);

    //====================================================
    // FSM STATE DEFINITIONS
    //====================================================
    // Each state represents an energy source or condition
    parameter SOLAR   = 3'b000;  // State 0: Supply from solar generation
    parameter BATTERY = 3'b001;  // State 1: Supply from battery storage
    parameter GRID    = 3'b010;  // State 2: Supply from grid (utility)
    parameter FAULT   = 3'b011;  // State 3: Fault condition (all sources disabled)
    parameter IDLE    = 3'b100;  // State 4: No load demand (efficiency state)

    reg [2:0] current_state, next_state;  // Current and next FSM state

    //====================================================
    // LOAD PREDICTION REGISTERS
    //====================================================
    // Linear extrapolation for anticipatory battery pre-charging
    reg [15:0] prev_load;       // Previous cycle load sample for trend
    reg [15:0] predicted_load;  // Extrapolated load (2*curr - prev)

    //====================================================
    // PWM & HYSTERESIS REGISTERS
    //====================================================
    reg [7:0] pwm_counter;      // Free-running counter for PWM generation
    reg [7:0] state_timer;      // Counts consecutive cycles in same state

    //====================================================
    // CONTROL PARAMETERS
    //====================================================
    // Battery SOC control thresholds
    parameter SOC_LOW  = 7'd20;   // Min safe SOC (switch to grid if below)
    parameter SOC_HIGH = 7'd60;   // Target SOC (well-charged, prefer solar/grid)

    // Peak-demand prediction: margin for precharge trigger
    parameter PRED_MARGIN = 16'd200;  // If (predicted_load > solar + MARGIN), precharge

    // State hysteresis: prevent rapid state oscillation
    parameter MIN_HOLD = 8'd8;  // Minimum cycles to hold each state

    //====================================================
    // STATE REGISTER
    //====================================================
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= GRID;
        else
            current_state <= next_state;
    end

    // state timer updates
    always @(posedge clk or posedge reset) begin
        if (reset)
            state_timer <= 8'd0;
        else if (current_state == next_state)
            state_timer <= state_timer + 8'd1;
        else
            state_timer <= 8'd0;
    end

    //====================================================
    // LOAD PREDICTION (simple extrapolation)
    // predicted_load = 2*load - prev_load
    //====================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_load <= 16'd0;
            predicted_load <= 16'd0;
        end else begin
            predicted_load <= (load << 1) - prev_load;
            prev_load <= load;
        end
    end

    //====================================================
    // PWM counter (for charge control)
    //====================================================
    always @(posedge clk or posedge reset) begin
        if (reset)
            pwm_counter <= 8'd0;
        else
            pwm_counter <= pwm_counter + 8'd1;
    end

    //====================================================
    // NEXT STATE LOGIC (with IDLE + hysteresis)
    //====================================================
    parameter IDLE = 3'b100;
    parameter MIN_HOLD = 8'd8; // minimum cycles to hold a state

    always @(*) begin

        next_state = current_state;

        //------------------------------------------------
        // HIGHEST PRIORITY = FAULT CHECK
        //------------------------------------------------
        if (battery_overtemp || overload ||
           (solar_fault && tariff_slot == 2'b01) ||
           (grid_fault  && current_state == GRID))
        begin
            next_state = FAULT;
        end

        // If there is no load, prefer IDLE state (quick transition)
        else if (load == 16'd0) begin
            next_state = IDLE;
        end

        // Enforce hysteresis: don't change state until MIN_HOLD elapsed
        else if (state_timer < MIN_HOLD) begin
            next_state = current_state;
        end

        else begin
            case(current_state)

            //--------------------------------------------
            // SOLAR MODE
            //--------------------------------------------
            SOLAR:
            begin
                if ((tariff_slot == 2'b00) || (solar < load)) begin
                    if (battery_soc > SOC_LOW)
                        next_state = BATTERY;
                    else
                        next_state = GRID;
                end
                else
                    next_state = SOLAR;
            end

            //--------------------------------------------
            // BATTERY MODE
            //--------------------------------------------
            BATTERY:
            begin
                if (battery_soc <= SOC_LOW)
                    next_state = GRID;

                else if ((tariff_slot == 2'b01) && (solar >= load))
                    next_state = SOLAR;

                else
                    next_state = BATTERY;
            end

            //--------------------------------------------
            // GRID MODE
            //--------------------------------------------
            GRID:
            begin
                // Peak tariff => prefer battery
                if (tariff_slot == 2'b10 && battery_soc > SOC_HIGH)
                    next_state = BATTERY;

                // Day + enough solar
                else if (tariff_slot == 2'b01 && solar >= load)
                    next_state = SOLAR;

                else
                    next_state = GRID;
            end

            //--------------------------------------------
            // FAULT MODE
            //--------------------------------------------
            FAULT:
            begin
                // Auto recover when all faults clear
                if (!(battery_overtemp || solar_fault || overload || grid_fault))
                    next_state = GRID;
                else
                    next_state = FAULT;
            end

            //--------------------------------------------
            // IDLE MODE
            //--------------------------------------------
            IDLE:
            begin
                if (load != 16'd0)
                    next_state = GRID; // fall back to GRID as default
                else
                    next_state = IDLE;
            end

            default:
                next_state = GRID;

            endcase
        end
    end

    //====================================================
    // OUTPUT LOGIC
    //====================================================
    always @(*) begin
        solar_mode   = 0;
        battery_mode = 0;
        grid_mode    = 0;
        fault_mode   = 0;
        fault_code   = 3'b000;
        idle_mode    = 0;
        // defaults for new outputs
        precharge_request = 1'b0;
        pwm_out = 1'b0;
        pwm_duty = 8'd0;

        case(current_state)

        //--------------------------------------------
        SOLAR:
            solar_mode = 1;

        //--------------------------------------------
        BATTERY:
            battery_mode = 1;

        //--------------------------------------------
        GRID:
            grid_mode = 1;

        //--------------------------------------------
        FAULT:
        begin
            fault_mode = 1;

            if (battery_overtemp)
                fault_code = 3'b001;
            else if (solar_fault)
                fault_code = 3'b010;
            else if (overload)
                fault_code = 3'b011;
            else if (grid_fault)
                fault_code = 3'b100;
            else
                fault_code = 3'b111;
        end

        //--------------------------------------------
        IDLE:
            idle_mode = 1;

        endcase

        // --------------------------------------------------
        // Peak prediction -> pre-charge decision
        // Only consider pre-charging during daytime (tariff_slot==01)
        // and when predicted load exceeds available solar by margin
        // and battery isn't already above SOC_HIGH.
        // --------------------------------------------------
        if (!fault_mode && (tariff_slot == 2'b01) && (battery_soc < SOC_HIGH)) begin
            if (predicted_load > (solar + PRED_MARGIN)) begin
                precharge_request = 1'b1;
                // duty scales with how far SOC is below target (SOC_HIGH)
                if (battery_soc < SOC_HIGH)
                    pwm_duty = (SOC_HIGH - battery_soc) << 2; // scale to 0-240 range
                else
                    pwm_duty = 8'd0;

                // PWM output based on counter
                pwm_out = (pwm_counter < pwm_duty) ? 1'b1 : 1'b0;
            end
        end
    end

endmodule