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

    output reg         solar_mode,
    output reg         battery_mode,
    output reg         grid_mode,
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

    // Internal signals (TB hierarchical access)
    reg  [15:0] total_load;   // dut.total_load
    integer     cost;         // dut.cost
    wire [6:0]  battery_soc;  // dut.battery_soc
    reg         charge_en, discharge_en;

    // Keep instance name for TB: dut.soc_ctrl.battery_soc
    battery_soc_controller soc_ctrl (
        .clk(clk),
        .reset(reset),
        .charge_en(charge_en),
        .discharge_en(discharge_en),
        .discharge_load(final_load),   // NEW
        .battery_soc(battery_soc)
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
    end

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

        // FIX #1: no-load -> Grid idle (never Solar at night)
        if (final_load == 0) begin
            grid_mode = 1'b1;
        end
        // FIX #1: night policy -> no solar mode selection
        else if (!day_flag && !peak_evening_flag) begin
            grid_mode = 1'b1;
        end
        // Day/Peak: prefer solar first
        else if (solar_generation >= final_load) begin
            solar_mode = 1'b1;
        end
        // Expensive periods fallback to battery if SOC healthy
        else if (battery_soc > MIN_SOC_FOR_DISCHARGE) begin
            battery_mode = 1'b1;
        end
        else begin
            grid_mode = 1'b1;
        end

        // FIX #2: operating cost model
        if (grid_mode)         cost = final_load * tariff_per_unit;
        else if (battery_mode) cost = final_load * BATTERY_COST_PER_UNIT;
        else                   cost = 0; // solar mode

        // SOC controls
        charge_en    = (solar_generation > final_load) && (battery_soc < 7'd100);
        discharge_en = battery_mode && (final_load != 0);
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