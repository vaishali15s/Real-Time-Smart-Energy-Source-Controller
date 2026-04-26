`timescale 1ns/1ps

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
    output reg [2:0]   fault_code,
    output reg         ac_supply,
    output reg         fridge_supply,
    output reg         wm_supply,
    output reg         fan_supply,
    output reg         bulb_supply,
    output reg [15:0]  final_load,
    output reg [3:0]   tariff_per_unit
);

    // Per-appliance load (units)
    localparam [15:0] AC_LOAD     = 16'd1500;
    localparam [15:0] FRIDGE_LOAD = 16'd300;
    localparam [15:0] WM_LOAD     = 16'd500;
    localparam [15:0] FAN_LOAD    = 16'd75;
    localparam [15:0] BULB_LOAD   = 16'd20;

    // Tariff
    localparam [3:0] RATE_NIGHT = 4'd5;
    localparam [3:0] RATE_DAY   = 4'd8;
    localparam [3:0] RATE_PEAK  = 4'd10;

    // Battery policy
    localparam [6:0] MIN_SOC_FOR_DISCHARGE = 7'd20;
    localparam integer BATTERY_COST_PER_UNIT = 2; // NEW: degradation/wear proxy
    localparam [15:0] OVERLOAD_LIMIT = 16'd2300;

    // Internal signals (TB hierarchical access)
    reg  [15:0] total_load;   // dut.total_load
    integer     cost;         // dut.cost
    wire [6:0]  battery_soc;  // dut.battery_soc
    reg         charge_en, discharge_en;
    reg  [1:0]  tariff_slot;
    wire        battery_overtemp, solar_fault, overload, grid_fault;
    wire        overload_auto;
    wire        fsm_solar_mode, fsm_battery_mode, fsm_grid_mode, fsm_fault_mode;
    wire [2:0]  fsm_fault_code;

    // Keep instance name for TB: dut.soc_ctrl.battery_soc
    battery_soc_controller soc_ctrl (
        .clk(clk),
        .reset(reset),
        .charge_en(charge_en),
        .discharge_en(discharge_en),
        .discharge_load(final_load),   // NEW
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
        .fault_code(fsm_fault_code)
    );

    // Requested total load
    always @(*) begin
        total_load = 16'd0;
        if (ac_on)     total_load = total_load + AC_LOAD;
        if (fridge_on) total_load = total_load + FRIDGE_LOAD;
        if (wm_on)     total_load = total_load + WM_LOAD;
        if (fan_on)    total_load = total_load + FAN_LOAD;
        if (bulb_on)   total_load = total_load + BULB_LOAD;
    end

    // Tariff select
    always @(*) begin
        if (peak_evening_flag)      tariff_per_unit = RATE_PEAK;  // 10
        else if (day_flag)          tariff_per_unit = RATE_DAY;   // 8
        else                        tariff_per_unit = RATE_NIGHT; // 5

        if (peak_evening_flag)      tariff_slot = 2'b10;
        else if (day_flag)          tariff_slot = 2'b01;
        else                        tariff_slot = 2'b00;
    end

    // Fault model hooks:
    // - solar_fault_in is treated as hazardous (trip-worthy) solar fault.
    // - normal low/zero solar generation is handled by source selection, not FAULT trip.
    assign overload_auto = (total_load > OVERLOAD_LIMIT);
    assign battery_overtemp = battery_overtemp_in;
    assign solar_fault = solar_fault_in;
    assign overload = overload_in | overload_auto;
    assign grid_fault = grid_fault_in;

    // Source + supply decision
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
            grid_mode = 1'b1;
        end
        else begin
            solar_mode = fsm_solar_mode;
            battery_mode = fsm_battery_mode;
            grid_mode = fsm_grid_mode;
            fault_mode = fsm_fault_mode;
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

        // FIX #2: operating cost model
        if (fault_mode)        cost = 0;
        else if (grid_mode)    cost = final_load * tariff_per_unit;
        else if (battery_mode) cost = final_load * BATTERY_COST_PER_UNIT;
        else                   cost = 0; // solar mode

        // SOC controls
        charge_en    = (!fault_mode) && (solar_generation > final_load) && (battery_soc < 7'd100);
        discharge_en = (!fault_mode) && battery_mode && (final_load != 0);
    end

endmodule


module battery_soc_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire        charge_en,
    input  wire        discharge_en,
    input  wire [15:0] discharge_load,  // NEW
    output reg  [6:0]  battery_soc
);
    reg [6:0] dec_step;
    integer q;

    always @(*) begin
        q = discharge_load / 16'd500;   // requested scaling
        if (q < 1)       dec_step = 7'd1;
        else if (q > 10) dec_step = 7'd10;
        else             dec_step = q[6:0];
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            battery_soc <= 7'd50;
        end else begin
            case ({charge_en, discharge_en})
                2'b10: if (battery_soc < 7'd100) battery_soc <= battery_soc + 7'd1;
                2'b01: begin
                    if (battery_soc > dec_step) battery_soc <= battery_soc - dec_step;
                    else                        battery_soc <= 7'd0;
                end
                default: battery_soc <= battery_soc;
            endcase
        end
    end
endmodule