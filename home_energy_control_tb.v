`timescale 1ns/1ps

module tb_home_energy_source_controller;

    reg clk;
    reg reset;
    reg ac_on, fan_on, wm_on, bulb_on, fridge_on;
    reg day_flag;
    reg peak_evening_flag;
    reg [15:0] solar_input;
    reg battery_overtemp_in, solar_fault_in, overload_in, grid_fault_in;

    integer total_cost;
    integer total_grid_cost;     // NEW
    integer total_battery_cost;  // NEW
    integer solar_cases, battery_cases, grid_cases, fault_cases, total_cases;
    integer ac_cases, fridge_cases, wm_cases, fan_cases, bulb_cases;
    integer overload_edge_pass, overload_edge_fail;
    integer solar_fault_pass, solar_fault_fail;
    integer multi_fault_pass, multi_fault_fail;
    integer fault_clear_pass, fault_clear_fail;
    integer soc_edge_pass, soc_edge_fail;
    integer tariff_switch_pass, tariff_switch_fail;

    real solar_pct, battery_pct, grid_pct;
    real ac_pct, fridge_pct, wm_pct, fan_pct, bulb_pct;

    wire solar_mode, battery_mode, grid_mode, fault_mode;
    wire [2:0] fault_code;
    wire ac_supply, fridge_supply, wm_supply, fan_supply, bulb_supply;
    wire [15:0] final_load;
    wire [3:0] tariff_per_unit;

    home_energy_source_controller dut (
        .clk(clk),
        .reset(reset),
        .ac_on(ac_on),
        .fan_on(fan_on),
        .wm_on(wm_on),
        .bulb_on(bulb_on),
        .fridge_on(fridge_on),
        .day_flag(day_flag),
        .peak_evening_flag(peak_evening_flag),
        .solar_generation(solar_input),
        .battery_overtemp_in(battery_overtemp_in),
        .solar_fault_in(solar_fault_in),
        .overload_in(overload_in),
        .grid_fault_in(grid_fault_in),
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode),
        .fault_mode(fault_mode),
        .fault_code(fault_code),
        .ac_supply(ac_supply),
        .fridge_supply(fridge_supply),
        .wm_supply(wm_supply),
        .fan_supply(fan_supply),
        .bulb_supply(bulb_supply),
        .final_load(final_load),
        .tariff_per_unit(tariff_per_unit)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task run_case;
        input [8*40-1:0] name;
        input i_ac, i_fan, i_wm, i_bulb, i_fridge, i_day, i_peak;
        input [15:0] i_solar;
        input i_battery_overtemp, i_solar_fault, i_overload, i_grid_fault;
        reg [8*8-1:0] slot_text;
        reg [8*8-1:0] mode_text;
        begin
            ac_on = i_ac;
            fan_on = i_fan;
            wm_on = i_wm;
            bulb_on = i_bulb;
            fridge_on = i_fridge;
            day_flag = i_day;
            peak_evening_flag = i_peak;
            solar_input = i_solar;
            battery_overtemp_in = i_battery_overtemp;
            solar_fault_in = i_solar_fault;
            overload_in = i_overload;
            grid_fault_in = i_grid_fault;

            #10;

            if ((solar_mode === 1'bx) || (battery_mode === 1'bx) || (grid_mode === 1'bx) || (fault_mode === 1'bx))
                $display("ERROR [%0t] %0s -> X detected in mode outputs", $time, name);

            if ((solar_mode + battery_mode + grid_mode + fault_mode) != 1)
                $display("ERROR [%0t] %0s -> mode not one-hot (S=%0b B=%0b G=%0b F=%0b)",
                         $time, name, solar_mode, battery_mode, grid_mode, fault_mode);

            if (peak_evening_flag) slot_text = "Peak";
            else if (day_flag)     slot_text = "Day";
            else                   slot_text = "Night";

            if (solar_mode)        mode_text = "Solar";
            else if (battery_mode) mode_text = "Battery";
            else if (grid_mode)    mode_text = "Grid";
            else if (fault_mode)   mode_text = "FAULT";
            else                   mode_text = "Invalid";

            if ((!day_flag && !peak_evening_flag) && solar_mode)
                $display("ERROR [%0t] %0s -> Solar selected at NIGHT", $time, name);

            if (fault_mode && (ac_supply || fridge_supply || wm_supply || fan_supply || bulb_supply || (dut.final_load != 16'd0)))
                $display("ERROR [%0t] %0s -> protection trip failed in FAULT mode", $time, name);

            $display("|%8t|%-24s|%-6s|%2d|%3d|%3d|%3d|%5d|%-7s|%1b|%2b|%2b|%2b|%2b|",
                     $time, name, slot_text, tariff_per_unit, dut.battery_soc,
                     dut.total_load, dut.final_load, dut.cost, mode_text,
                     ac_supply, fridge_supply, wm_supply, fan_supply, bulb_supply);

            if (fault_mode)
                $display("  -> FAULT asserted, fault_code=%03b", fault_code);

            total_cost = total_cost + dut.cost; // total operating cost
            if (grid_mode)    total_grid_cost    = total_grid_cost + dut.cost;    // FIX
            if (battery_mode) total_battery_cost = total_battery_cost + dut.cost; // optional split
            total_cases = total_cases + 1;

            if (ac_supply)     ac_cases = ac_cases + 1;
            if (fridge_supply) fridge_cases = fridge_cases + 1;
            if (wm_supply)     wm_cases = wm_cases + 1;
            if (fan_supply)    fan_cases = fan_cases + 1;
            if (bulb_supply)   bulb_cases = bulb_cases + 1;

            if (solar_mode)        solar_cases = solar_cases + 1;
            else if (battery_mode) battery_cases = battery_cases + 1;
            else if (grid_mode)    grid_cases = grid_cases + 1;
            else if (fault_mode)   fault_cases = fault_cases + 1;
        end
    endtask

    task expect_state;
        input [8*40-1:0] name;
        input exp_solar, exp_battery, exp_grid, exp_fault;
        input check_fault_code;
        input [2:0] exp_fault_code;
        input [8*24-1:0] group_name;
        input group_mode;
        input group_fault;
        begin
            if ((solar_mode !== exp_solar) ||
                (battery_mode !== exp_battery) ||
                (grid_mode !== exp_grid) ||
                (fault_mode !== exp_fault))
            begin
                $display("ERROR [%0t] %0s -> expected mode S=%0b B=%0b G=%0b F=%0b, got S=%0b B=%0b G=%0b F=%0b",
                         $time, name,
                         exp_solar, exp_battery, exp_grid, exp_fault,
                         solar_mode, battery_mode, grid_mode, fault_mode);
                if (group_mode == 1'b0) begin
                    // keep a single failure bucket per scenario group
                end
            end

            if (check_fault_code && (fault_code !== exp_fault_code)) begin
                $display("ERROR [%0t] %0s -> expected fault_code=%03b, got %03b",
                         $time, name, exp_fault_code, fault_code);
            end

            if (group_name == "OVERLOAD") begin
                if ((solar_mode === exp_solar) && (battery_mode === exp_battery) && (grid_mode === exp_grid) && (fault_mode === exp_fault)) overload_edge_pass = overload_edge_pass + 1;
                else overload_edge_fail = overload_edge_fail + 1;
            end else if (group_name == "SOLARFLT") begin
                if ((solar_mode === exp_solar) && (battery_mode === exp_battery) && (grid_mode === exp_grid) && (fault_mode === exp_fault)) solar_fault_pass = solar_fault_pass + 1;
                else solar_fault_fail = solar_fault_fail + 1;
            end else if (group_name == "MULTIFLT") begin
                if ((solar_mode === exp_solar) && (battery_mode === exp_battery) && (grid_mode === exp_grid) && (fault_mode === exp_fault)) multi_fault_pass = multi_fault_pass + 1;
                else multi_fault_fail = multi_fault_fail + 1;
            end else if (group_name == "CLEARFLT") begin
                if ((solar_mode === exp_solar) && (battery_mode === exp_battery) && (grid_mode === exp_grid) && (fault_mode === exp_fault)) fault_clear_pass = fault_clear_pass + 1;
                else fault_clear_fail = fault_clear_fail + 1;
            end else if (group_name == "SOCTHRES") begin
                if ((solar_mode === exp_solar) && (battery_mode === exp_battery) && (grid_mode === exp_grid) && (fault_mode === exp_fault)) soc_edge_pass = soc_edge_pass + 1;
                else soc_edge_fail = soc_edge_fail + 1;
            end else if (group_name == "TARIFF") begin
                if ((solar_mode === exp_solar) && (battery_mode === exp_battery) && (grid_mode === exp_grid) && (fault_mode === exp_fault)) tariff_switch_pass = tariff_switch_pass + 1;
                else tariff_switch_fail = tariff_switch_fail + 1;
            end
        end
    endtask

    initial begin
        total_cost = 0;
        total_grid_cost = 0;      // NEW
        total_battery_cost = 0;   // NEW
        solar_cases = 0; battery_cases = 0; grid_cases = 0; fault_cases = 0; total_cases = 0;
        ac_cases = 0; fridge_cases = 0; wm_cases = 0; fan_cases = 0; bulb_cases = 0;
        overload_edge_pass = 0; overload_edge_fail = 0;
        solar_fault_pass = 0; solar_fault_fail = 0;
        multi_fault_pass = 0; multi_fault_fail = 0;
        fault_clear_pass = 0; fault_clear_fail = 0;
        soc_edge_pass = 0; soc_edge_fail = 0;
        tariff_switch_pass = 0; tariff_switch_fail = 0;

        reset = 1;
        ac_on = 0; fan_on = 0; wm_on = 0; bulb_on = 0; fridge_on = 0;
        day_flag = 0; peak_evening_flag = 0; solar_input = 0;
        battery_overtemp_in = 0; solar_fault_in = 0; overload_in = 0; grid_fault_in = 0;
        #12 reset = 0;

        $display("\n+----------------------------------------------------------------------------------------------------------------+");
        $display("|Time(ns)|Case                    |Slot  |Rt|SOC|Dem|Srv|Cost |Mode   |A|Fr|Wm|Fn|Bu|");
        $display("+----------------------------------------------------------------------------------------------------------------+");

        run_case("N1 Night no load",         0,0,0,0,0,0,0,0,    0,0,0,0);
        run_case("N2 Night medium load",     1,1,0,1,0,0,0,0,    0,0,0,0);
        run_case("D1 Day light load",        0,1,0,1,0,1,0,14000,0,0,0,0);
        run_case("D2 Day high load",         1,0,1,0,1,1,0,2000, 0,0,0,0);

        dut.soc_ctrl.battery_soc = 7'd35;
        run_case("P1 Peak high SOC",         1,0,1,0,1,0,1,300,  0,0,0,0);

        dut.soc_ctrl.battery_soc = 7'd10;
        run_case("P2 Peak low SOC fallback", 1,0,1,0,1,0,1,300,  0,0,0,0);

        // Overload threshold validation (limit = 2300, condition is > limit)
        run_case("E1 Overload edge equal",   1,0,1,0,1,1,0,2000, 0,0,0,0); // 2300 exact
        expect_state("E1 Overload edge equal", 0,0,1,0, 0, 3'b000, "OVERLOAD", 1'b1, 1'b0);
        run_case("E2 Overload edge above",   1,1,1,1,1,1,0,2000, 0,0,0,0); // 2395
        expect_state("E2 Overload edge above", 0,0,0,1, 1, 3'b011, "OVERLOAD", 1'b1, 1'b1);

        // Solar unavailable should fallback, not FAULT trip
        dut.soc_ctrl.battery_soc = 7'd35;
        run_case("F1 Solar unavailable",     1,0,0,1,0,1,0,0,    0,0,0,0);
        expect_state("F1 Solar unavailable", 0,0,1,0, 0, 3'b000, "SOLARFLT", 1'b1, 1'b0);

        // Explicit hazardous solar fault input trips FAULT
        run_case("F2 Solar hazard fault",    1,0,0,1,0,1,0,1000, 0,1,0,0);
        expect_state("F2 Solar hazard fault", 0,0,0,1, 1, 3'b010, "SOLARFLT", 1'b1, 1'b1);

        run_case("F3 Battery overtemp",      1,1,0,1,1,1,0,500,  1,0,0,0);
        expect_state("F3 Battery overtemp", 0,0,0,1, 1, 3'b001, "MULTIFLT", 1'b1, 1'b1);

        dut.soc_ctrl.battery_soc = 7'd10;
        run_case("F4 Grid fault trip",       1,0,0,0,0,0,0,0,    0,0,0,1);
        expect_state("F4 Grid fault trip", 0,0,0,1, 1, 3'b100, "MULTIFLT", 1'b1, 1'b1);
        run_case("F5 Overload trip",         1,1,1,1,1,1,0,2000, 0,0,1,0);
        expect_state("F5 Overload trip", 0,0,0,1, 1, 3'b011, "OVERLOAD", 1'b1, 1'b1);

        // Simultaneous faults: verify priority encoding (battery_overtemp highest)
        run_case("F6 Multi-fault priority",  1,0,0,1,0,1,0,1000, 1,1,1,1);
        expect_state("F6 Multi-fault priority", 0,0,0,1, 1, 3'b001, "MULTIFLT", 1'b1, 1'b1);

        // Fault clears for one cycle, then returns
        run_case("F7 Fault active",          1,0,0,1,0,1,0,1000, 1,0,0,0);
        expect_state("F7 Fault active", 0,0,0,1, 1, 3'b001, "CLEARFLT", 1'b1, 1'b1);
        run_case("F8 Fault clear 1 cycle",   1,0,0,1,0,1,0,1000, 0,0,0,0);
        expect_state("F8 Fault clear 1 cycle", 0,0,1,0, 0, 3'b000, "CLEARFLT", 1'b1, 1'b0);
        run_case("F9 Fault returns",         1,0,0,1,0,1,0,1000, 1,0,0,0);
        expect_state("F9 Fault returns", 0,0,0,1, 1, 3'b001, "CLEARFLT", 1'b1, 1'b1);

        // SOC threshold edges
        run_case("S0 Enter SOLAR",           0,1,0,1,0,1,0,14000,0,0,0,0);
        dut.soc_ctrl.battery_soc = 7'd20;
        run_case("S1 SOC low exact",         0,1,0,1,0,1,0,10,   0,0,0,0);
        expect_state("S1 SOC low exact", 0,0,1,0, 0, 3'b000, "SOCTHRES", 1'b1, 1'b0);
        run_case("S2 Back SOLAR",            0,1,0,1,0,1,0,14000,0,0,0,0);
        dut.soc_ctrl.battery_soc = 7'd21;
        run_case("S3 SOC low plus one",      0,1,0,1,0,1,0,10,   0,0,0,0);
        expect_state("S3 SOC low plus one", 0,1,0,0, 0, 3'b000, "SOCTHRES", 1'b1, 1'b0);

        // Force FSM back to known GRID baseline for SOC_HIGH edge testing.
        reset = 1;
        #10;
        reset = 0;
        #10;

        dut.soc_ctrl.battery_soc = 7'd60;
        run_case("S4 SOC high exact",        1,0,1,0,1,0,1,10,   0,0,0,0);
        expect_state("S4 SOC high exact", 0,0,1,0, 0, 3'b000, "SOCTHRES", 1'b1, 1'b0);
        dut.soc_ctrl.battery_soc = 7'd61;
        run_case("S5 SOC high plus one",     1,0,1,0,1,0,1,10,   0,0,0,0);
        expect_state("S5 SOC high plus one", 0,1,0,0, 0, 3'b000, "SOCTHRES", 1'b1, 1'b1);

        // Rapid tariff switching
        dut.soc_ctrl.battery_soc = 7'd80;
        run_case("T1 Rapid Day",             0,1,0,1,0,1,0,14000,0,0,0,0);
        expect_state("T1 Rapid Day", 1,0,0,0, 0, 3'b000, "TARIFF", 1'b1, 1'b1);
        run_case("T2 Rapid Peak",            0,1,0,1,0,0,1,10,   0,0,0,0);
        expect_state("T2 Rapid Peak", 0,1,0,0, 0, 3'b000, "TARIFF", 1'b1, 1'b1);
        run_case("T3 Rapid Night",           0,1,0,1,0,0,0,10,   0,0,0,0);
        expect_state("T3 Rapid Night", 0,1,0,0, 0, 3'b000, "TARIFF", 1'b1, 1'b1);
        run_case("T4 Rapid Day",             0,1,0,1,0,1,0,14000,0,0,0,0);
        expect_state("T4 Rapid Day", 1,0,0,0, 0, 3'b000, "TARIFF", 1'b1, 1'b1);

        // Recovery after all faults clear
        run_case("R1 Fault clear recovery",  1,1,0,1,0,0,0,0,    0,0,0,0);
        expect_state("R1 Fault clear recovery", 0,1,0,0, 0, 3'b000, "CLEARFLT", 1'b1, 1'b1);

        solar_pct   = (total_cases == 0) ? 0.0 : (solar_cases   * 100.0) / total_cases;
        battery_pct = (total_cases == 0) ? 0.0 : (battery_cases * 100.0) / total_cases;
        grid_pct    = (total_cases == 0) ? 0.0 : (grid_cases    * 100.0) / total_cases;

        ac_pct      = (total_cases == 0) ? 0.0 : (ac_cases      * 100.0) / total_cases;
        fridge_pct  = (total_cases == 0) ? 0.0 : (fridge_cases  * 100.0) / total_cases;
        wm_pct      = (total_cases == 0) ? 0.0 : (wm_cases      * 100.0) / total_cases;
        fan_pct     = (total_cases == 0) ? 0.0 : (fan_cases     * 100.0) / total_cases;
        bulb_pct    = (total_cases == 0) ? 0.0 : (bulb_cases    * 100.0) / total_cases;

        $display("\nTotal Operating Cost: %0d", total_cost);
        $display("Total Grid Cost:      %0d", total_grid_cost);      // FIXED
        $display("Total Battery Cost:   %0d\n", total_battery_cost);  // optional
        $display("Fault Cases:          %0d\n", fault_cases);
        $display("+----------------------+--------+--------+");
        $display("| Group                | Pass   | Fail   |");
        $display("+----------------------+--------+--------+");
        $display("| Overload threshold   | %6d | %6d |", overload_edge_pass, overload_edge_fail);
        $display("| Solar fault policy    | %6d | %6d |", solar_fault_pass, solar_fault_fail);
        $display("| Multi-fault priority  | %6d | %6d |", multi_fault_pass, multi_fault_fail);
        $display("| Fault clear/recover   | %6d | %6d |", fault_clear_pass, fault_clear_fail);
        $display("| SOC thresholds        | %6d | %6d |", soc_edge_pass, soc_edge_fail);
        $display("| Tariff switching      | %6d | %6d |", tariff_switch_pass, tariff_switch_fail);
        $display("+----------------------+--------+--------+");
        #20 $finish;
    end

endmodule