`timescale 1ns/1ps

//============================================================================
// HOME ENERGY SOURCE CONTROLLER (TOP-LEVEL SYSTEM MODULE)
//============================================================================\n// Orchestrates smart home energy management across multiple sources
// (solar, battery, grid) with tariff-aware selection and fault protection.
//
// ARCHITECTURE:\n//   1. Load calculation: Sum appliance power demands
//   2. Tariff mapping: Select pricing tier based on time-of-use
//   3. Fault aggregation: Collect and decode fault signals
//   4. FSM control: Run energy_fsm for source selection
//   5. Battery management: Run battery_soc_controller for SOC tracking
//   6. Cost calculation: Track grid cost and battery wear cost
//   7. Load gating: Disconnect appliances during fault
//
// MAIN OUTPUTS:\n//   - Mode indicators: solar_mode, battery_mode, grid_mode, fault_mode, idle_mode
//   - Appliance supplies: ac_supply, fridge_supply, wm_supply, fan_supply, bulb_supply
//   - Cost tracking: grid_cost, battery_wear_cost, total_operating_cost
//============================================================================

module home_energy_source_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire        ac_on,
    input  wire        fan_on,
    input  wire        wm_on,
    input  wire        bulb_on,
    input  wire        fridge_on,
    input  wire        day_flag,
    input  wire        peak_evening_flag,
    input  wire [15:0] solar_generation,
    input  wire        battery_overtemp_in,
    input  wire        solar_fault_in,
    input  wire        overload_in,
    input  wire        grid_fault_in,

    output reg         solar_mode,
    output reg         battery_mode,
    output reg         grid_mode,
    output reg         fault_mode,
    output reg         idle_mode,
    output reg [2:0]   fault_code,
    output reg         ac_supply,
    output reg         fridge_supply,
    output reg         wm_supply,
    output reg         fan_supply,
    output reg         bulb_supply,
    output reg [15:0]  final_load,
    output reg [3:0]   tariff_per_unit
);

    // Per-appliance load (units - watts equivalent)
    //   Each appliance has a nominal power consumption in watts
    localparam [15:0] AC_LOAD     = 16'd1500;  // Air conditioner
    localparam [15:0] FRIDGE_LOAD = 16'd300;   // Refrigerator\n    localparam [15:0] WM_LOAD     = 16'd500;   // Washing machine
    localparam [15:0] FAN_LOAD    = 16'd75;    // Fan
    localparam [15:0] BULB_LOAD   = 16'd20;    // Light bulb

    // Time-of-use tariff rates (₹ per unit or equivalent cost)
    //   Rates vary by time period to incentivize off-peak usage
    localparam [3:0] RATE_NIGHT = 4'd5;   // Off-peak (lowest cost)
    localparam [3:0] RATE_DAY   = 4'd8;   // Mid-peak
    localparam [3:0] RATE_PEAK  = 4'd10;  // Peak evening (highest cost)

    // Battery and protection parameters
    localparam [6:0] MIN_SOC_FOR_DISCHARGE = 7'd20;  // Don't discharge below 20% SOC
    localparam integer BATTERY_COST_PER_UNIT = 2;    // Wear cost per unit (proxy for degradation)
    localparam [15:0] OVERLOAD_LIMIT = 16'd2300;     // Maximum safe load (W)

    // Internal signals (TB hierarchical access)
    // Energy tracking
    reg  [15:0] total_load;   // Aggregate load from all active appliances

    // Cost tracking (renamed for clarity)
    integer     grid_cost;            // Cost of electricity from grid (₹)
    integer     battery_wear_cost;    // Proxy cost for battery degradation (₹)
    integer     total_operating_cost; // Sum of grid + battery wear costs
    integer     cost;                 // Legacy alias for testbench compatibility

    // Battery state
    wire [6:0]  battery_soc;  // Battery state-of-charge (0-100%)

    // Time-of-use control
    reg  [1:0]  tariff_slot;  // Encoded tariff: 00=Night, 01=Day, 10=Peak

    // Fault handling
    wire        battery_overtemp, solar_fault, overload, grid_fault;  // Fault signals
    wire        overload_auto;  // Auto-detected overload (load > LIMIT)

    // FSM (Finite State Machine) interconnects
    wire        fsm_solar_mode, fsm_battery_mode, fsm_grid_mode, fsm_fault_mode;
    wire [2:0]  fsm_fault_code;
    wire        fsm_idle_mode;

    // Peak-demand prediction & PWM charging
    wire        fsm_precharge_request;  // FSM request to pre-charge battery
    wire        fsm_pwm_out;            // PWM control signal
    wire [7:0]  fsm_pwm_duty;           // PWM duty cycle

    // Charging control
    wire        allow_charge;  // Gate signal: allow charging only when no fault

    //==========================================================================\n    // CHARGING GATE LOGIC\n    //==========================================================================\n    // Prevent battery charging during faults for safety.\n    // Charging allowed only when no fault mode is active.\n    assign allow_charge = !fsm_fault_mode;\n\n    //==========================================================================\n    // BATTERY SOC CONTROLLER INSTANTIATION\n    //==========================================================================\n    // Manages battery state-of-charge tracking and charging/discharging logic.\n    // Connected to:\n    //   - FSM precharge_request for anticipatory peak-demand charging\n    //   - allow_charge gate for fault protection\n    // Outputs battery_soc used by FSM and top-level outputs\n    //==========================================================================\n    // Use external battery_soc_controller implementation\n    // Keep instance name for TB: dut.soc_ctrl.battery_soc\n    battery_soc_controller soc_ctrl (
        .clk(clk),
        .reset(reset),
        .load(final_load),
        .solar(solar_generation),
        .battery_mode(battery_mode),
        .allow_charge(allow_charge),
        .precharge_request(fsm_precharge_request),
        .battery_soc(battery_soc)
    );

    energy_fsm fsm_ctrl (
        .clk(clk),
        .reset(reset),
        .load(total_load),
        .solar(solar_generation),
        .battery_soc(battery_soc),
        .tariff_slot(tariff_slot),
        .battery_overtemp(battery_overtemp),
        .solar_fault(solar_fault),
        .overload(overload),
        .grid_fault(grid_fault),
        .solar_mode(fsm_solar_mode),
        .battery_mode(fsm_battery_mode),
        .grid_mode(fsm_grid_mode),
        .fault_mode(fsm_fault_mode),
        .fault_code(fsm_fault_code),
        .precharge_request(fsm_precharge_request),
        .pwm_out(fsm_pwm_out),
        .pwm_duty(fsm_pwm_duty),
        .idle_mode(fsm_idle_mode)
    );

    //==========================================================================
    // APPLIANCE LOAD CALCULATION (Combinational Logic)
    //==========================================================================
    // Aggregates individual appliance power demands into total system load.
    // Each appliance power is added only if its on/off signal is asserted.
    // Used by FSM for source selection and battery discharge rate calculation.
    //==========================================================================
    // Requested total load
    always @(*) begin
        total_load = 16'd0;
        if (ac_on)     total_load = total_load + AC_LOAD;
        if (fridge_on) total_load = total_load + FRIDGE_LOAD;
        if (wm_on)     total_load = total_load + WM_LOAD;
        if (fan_on)    total_load = total_load + FAN_LOAD;
        if (bulb_on)   total_load = total_load + BULB_LOAD;
    end

    //==========================================================================
    // TIME-OF-USE TARIFF SELECTION (Combinational Logic)
    //==========================================================================
    // Selects electricity rate and tariff slot based on time-of-day flags.
    // Priorities:
    //   1. Peak evening (highest cost): Encourage battery/solar use
    //   2. Daytime (medium cost): Encourage solar charging
    //   3. Night (lowest cost): Off-peak, grid-friendly period
    // Output: tariff_per_unit (rate in ₹/kWh) and tariff_slot (FSM selector)
    //==========================================================================
    // Tariff select
    always @(*) begin
        if (peak_evening_flag)      tariff_per_unit = RATE_PEAK;  // 10
        else if (day_flag)          tariff_per_unit = RATE_DAY;   // 8
        else                        tariff_per_unit = RATE_NIGHT; // 5

        if (peak_evening_flag)      tariff_slot = 2'b10;
        else if (day_flag)          tariff_slot = 2'b01;
        else                        tariff_slot = 2'b00;
    end

    //==========================================================================
    // FAULT DETECTION & AGGREGATION (Combinational Logic)
    //==========================================================================
    // Collects individual fault signals and detects auto-overload condition.
    // Fault handling philosophy:
    //   - External faults (battery temp, solar, grid) passed directly
    //   - Overload detected as: (total_load > OVERLOAD_LIMIT) OR external flag
    //   - Note: Low/zero solar during day is NOT a fault (handled by FSM)
    //==========================================================================
    // Fault model hooks:
    // - solar_fault_in is treated as hazardous (trip-worthy) solar fault.
    // - normal low/zero solar generation is handled by source selection, not FAULT trip.
    assign overload_auto = (total_load > OVERLOAD_LIMIT);
    assign battery_overtemp = battery_overtemp_in;
    assign solar_fault = solar_fault_in;
    assign overload = overload_in | overload_auto;
    assign grid_fault = grid_fault_in;

    //==========================================================================
    // SOURCE SELECTION & APPLIANCE SUPPLY DECISION (Combinational Logic)
    //==========================================================================
    // Main decision engine for energy source and appliance control:
    //   1. Calculate total load from active appliances
    //   2. Map FSM output modes to final output signals
    //   3. Handle IDLE state (no load = no source)
    //   4. Restrict solar use at night (even if FSM requests)
    //   5. Disconnect appliances during fault (safety)
    //   6. Calculate operating costs
    //==========================================================================
    always @(*) begin
        ac_supply     = ac_on;
        fridge_supply = fridge_on;
        wm_supply     = wm_on;
        fan_supply    = fan_on;
        bulb_supply   = bulb_on;
        final_load    = total_load;

        solar_mode   = 1'b0;
        battery_mode = 1'b0;
        grid_mode    = 1'b0;
        fault_mode   = 1'b0;
        fault_code   = 3'b000;

        // Keep no-load behavior deterministic for TB checks.
        if (final_load == 0) begin
            // Enter IDLE when there's no demand
            idle_mode = 1'b1;
            solar_mode = 1'b0;
            battery_mode = 1'b0;
            grid_mode = 1'b0;
            fault_mode = 1'b0;
            fault_code = 3'b000;
        end
        else begin
            solar_mode = fsm_solar_mode;
            battery_mode = fsm_battery_mode;
            grid_mode = fsm_grid_mode;
            fault_mode = fsm_fault_mode;
            idle_mode = fsm_idle_mode;
            fault_code = fsm_fault_code;

            if (!day_flag && !peak_evening_flag && solar_mode) begin
                solar_mode = 1'b0;
                if (battery_soc > MIN_SOC_FOR_DISCHARGE)
                    battery_mode = 1'b1;
                else
                    grid_mode = 1'b1;
            end

            // Protection trip behavior in FAULT mode.
            if (fault_mode) begin
                solar_mode = 1'b0;
                battery_mode = 1'b0;
                grid_mode = 1'b0;
                ac_supply = 1'b0;
                fridge_supply = 1'b0;
                wm_supply = 1'b0;
                fan_supply = 1'b0;
                bulb_supply = 1'b0;
                final_load = 16'd0;
            end
        end

        // Operating cost model (renamed):
        // - grid_cost: cost of electricity when grid supplies load
        // - battery_wear_cost: proxy cost for using battery (degradation)
        if (fault_mode) begin
            grid_cost = 0;
            battery_wear_cost = 0;
        end else begin
            if (grid_mode)      grid_cost = final_load * tariff_per_unit;
            else                grid_cost = 0;

            if (battery_mode)   battery_wear_cost = final_load * BATTERY_COST_PER_UNIT;
            else                battery_wear_cost = 0;
        end
        total_operating_cost = grid_cost + battery_wear_cost;
        cost = total_operating_cost; // legacy alias for tests/TB

        // SOC is handled inside `battery_soc_controller` (charging when solar > load,
        // discharging when `battery_mode` is asserted). The FSM's precharge_request
        // still influences system-level charging decisions via other actuators.
    end

endmodule
