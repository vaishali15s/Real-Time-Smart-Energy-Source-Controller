`timescale 1ns/1ps

module tb_home_energy_source_controller;

    reg clk;
    reg reset;
    reg ac_on, fan_on, wm_on, bulb_on, fridge_on;
    reg day_flag;
    reg peak_evening_flag;
    reg [15:0] solar_input;

    integer total_cost;
    integer total_grid_cost;     // NEW
    integer total_battery_cost;  // NEW
    integer solar_cases, battery_cases, grid_cases, total_cases;
    integer ac_cases, fridge_cases, wm_cases, fan_cases, bulb_cases;

    real solar_pct, battery_pct, grid_pct;
    real ac_pct, fridge_pct, wm_pct, fan_pct, bulb_pct;

    wire solar_mode, battery_mode, grid_mode;
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
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode),
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
        reg [8*8-1:0] slot_text;
        reg [8*7-1:0] mode_text;
        begin
            ac_on = i_ac;
            fan_on = i_fan;
            wm_on = i_wm;
            bulb_on = i_bulb;
            fridge_on = i_fridge;
            day_flag = i_day;
            peak_evening_flag = i_peak;
            solar_input = i_solar;

            #10;

            if ((solar_mode === 1'bx) || (battery_mode === 1'bx) || (grid_mode === 1'bx))
                $display("ERROR [%0t] %0s -> X detected in mode outputs", $time, name);

            if ((solar_mode + battery_mode + grid_mode) != 1)
                $display("ERROR [%0t] %0s -> mode not one-hot (S=%0b B=%0b G=%0b)",
                         $time, name, solar_mode, battery_mode, grid_mode);

            if (peak_evening_flag) slot_text = "Peak";
            else if (day_flag)     slot_text = "Day";
            else                   slot_text = "Night";

            if (solar_mode)        mode_text = "Solar";
            else if (battery_mode) mode_text = "Battery";
            else if (grid_mode)    mode_text = "Grid";
            else                   mode_text = "Invalid";

            if ((!day_flag && !peak_evening_flag) && solar_mode)
                $display("ERROR [%0t] %0s -> Solar selected at NIGHT", $time, name);

            $display("|%8t|%-24s|%-6s|%2d|%3d|%3d|%3d|%5d|%-7s|%1b|%2b|%2b|%2b|%2b|",
                     $time, name, slot_text, tariff_per_unit, dut.battery_soc,
                     dut.total_load, dut.final_load, dut.cost, mode_text,
                     ac_supply, fridge_supply, wm_supply, fan_supply, bulb_supply);

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
        end
    endtask

    initial begin
        total_cost = 0;
        total_grid_cost = 0;      // NEW
        total_battery_cost = 0;   // NEW
        solar_cases = 0; battery_cases = 0; grid_cases = 0; total_cases = 0;
        ac_cases = 0; fridge_cases = 0; wm_cases = 0; fan_cases = 0; bulb_cases = 0;

        reset = 1;
        ac_on = 0; fan_on = 0; wm_on = 0; bulb_on = 0; fridge_on = 0;
        day_flag = 0; peak_evening_flag = 0; solar_input = 0;
        #12 reset = 0;

        $display("\n+----------------------------------------------------------------------------------------------------------------+");
        $display("|Time(ns)|Case                    |Slot  |Rt|SOC|Dem|Srv|Cost |Mode   |A|Fr|Wm|Fn|Bu|");
        $display("+----------------------------------------------------------------------------------------------------------------+");

        run_case("N1 Night no load",         0,0,0,0,0,0,0,0);
        run_case("N2 Night medium load",     1,1,0,1,0,0,0,0);
        run_case("D1 Day light load",        0,1,0,1,0,1,0,14000);
        run_case("D2 Day high load",         1,1,1,1,1,1,0,2000);

        dut.soc_ctrl.battery_soc = 7'd35;
        run_case("P1 Peak high SOC",         1,1,1,1,1,0,1,300);

        dut.soc_ctrl.battery_soc = 7'd10;
        run_case("P2 Peak low SOC fallback", 1,1,1,1,1,0,1,300);

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
        #20 $finish;
    end

endmodule