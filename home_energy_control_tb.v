`timescale 1ns/1ps

module tb_home_energy_source_controller;

    reg clk;
    reg reset;
    reg ac_on, fan_on, wm_on, bulb_on, fridge_on;
    reg day_flag;
    reg [15:0] solar_input;
    integer total_cost;
    integer solar_cases;
    integer battery_cases;
    integer grid_cases;
    integer total_cases;
    integer ac_cases;
    integer fridge_cases;
    integer wm_cases;
    integer fan_cases;
    integer bulb_cases;
    real solar_pct;
    real battery_pct;
    real grid_pct;
    real ac_pct;
    real fridge_pct;
    real wm_pct;
    real fan_pct;
    real bulb_pct;

    wire solar_mode, battery_mode, grid_mode;
    wire ac_supply, fridge_supply, wm_supply, fan_supply, bulb_supply;
    wire [15:0] final_load;

    // DUT
    home_energy_source_controller dut (
        .clk(clk),
        .reset(reset),
        .ac_on(ac_on),
        .fan_on(fan_on),
        .wm_on(wm_on),
        .bulb_on(bulb_on),
        .fridge_on(fridge_on),
        .day_flag(day_flag),
        .solar_generation(solar_input),
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode),
        .ac_supply(ac_supply),
        .fridge_supply(fridge_supply),
        .wm_supply(wm_supply),
        .fan_supply(fan_supply),
        .bulb_supply(bulb_supply),
        .final_load(final_load)
    );

    // Clock (even if currently unused)
    initial clk = 0;
    always #5 clk = ~clk;

    task run_case;
        input [8*40-1:0] name;
        input i_ac, i_fan, i_wm, i_bulb, i_fridge, i_day;
        input [15:0] i_solar;
        reg [8*5-1:0] day_text;
        reg [8*7-1:0] mode_text;
        begin
            ac_on = i_ac;
            fan_on = i_fan;
            wm_on = i_wm;
            bulb_on = i_bulb;
            fridge_on = i_fridge;
            day_flag = i_day;
            solar_input = i_solar;

            #10; // wait for combinational settle

            // Basic validity checks
            if ((solar_mode === 1'bx) || (battery_mode === 1'bx) || (grid_mode === 1'bx))
                $display("ERROR [%0t] %0s -> X detected in outputs", $time, name);

            if ((solar_mode + battery_mode + grid_mode) != 1)
                $display("ERROR [%0t] %0s -> outputs not one-hot: S=%0b B=%0b G=%0b",
                         $time, name, solar_mode, battery_mode, grid_mode);

            day_text = day_flag ? "Day" : "Night";

            if (solar_mode)
                mode_text = "Solar";
            else if (battery_mode)
                mode_text = "Battery";
            else if (grid_mode)
                mode_text = "Grid";
            else
                mode_text = "Invalid";

            $display("|%8t|%-24s|%-5s|%3d|%3d|%3d|%5d|%-5s|%1b|%2b|%2b|%2b|%2b|",
                     $time, name, day_text, dut.battery_soc,
                     dut.total_load, dut.final_load, dut.cost,
                     mode_text,
                     ac_supply, fridge_supply, wm_supply, fan_supply, bulb_supply);

            total_cost = total_cost + dut.cost;
            total_cases = total_cases + 1;

            if (ac_supply)
                ac_cases = ac_cases + 1;
            if (fridge_supply)
                fridge_cases = fridge_cases + 1;
            if (wm_supply)
                wm_cases = wm_cases + 1;
            if (fan_supply)
                fan_cases = fan_cases + 1;
            if (bulb_supply)
                bulb_cases = bulb_cases + 1;

            if (solar_mode)
                solar_cases = solar_cases + 1;
            else if (battery_mode)
                battery_cases = battery_cases + 1;
            else if (grid_mode)
                grid_cases = grid_cases + 1;
        end
    endtask

    initial begin
        // Init
        total_cost = 0;
        solar_cases = 0;
        battery_cases = 0;
        grid_cases = 0;
        total_cases = 0;
        ac_cases = 0;
        fridge_cases = 0;
        wm_cases = 0;
        fan_cases = 0;
        bulb_cases = 0;
        reset = 1;
        ac_on = 0; fan_on = 0; wm_on = 0; bulb_on = 0; fridge_on = 0;
        day_flag = 0; solar_input = 0;

        #12;
        reset = 0;

        $display("\n+---------------------------------------------------------------------------------------------+");
        $display("|Time(ns)|Case                    |Day  |SOC|Dem|Srv|Cost |Mode |A|Fr|Wm|Fn|Bu|");
        $display("+---------------------------------------------------------------------------------------------+");

        // Test scenarios
        run_case("C1 Day no load",          0,0,0,0,0,1,14000);
        run_case("C2 Day light load",       0,1,0,1,0,1,14000);
        run_case("C3 Day high load",        1,1,1,1,1,1,2000);
        run_case("C4 Day high load",        1,1,1,1,1,1,2000);
        run_case("C5 Night medium load",    1,1,0,1,0,0,0);
        run_case("C6 Night medium load",    1,1,0,1,0,0,0);
        run_case("C7 Night no load",        0,0,0,0,0,0,0);

        solar_pct = (total_cases == 0) ? 0.0 : (solar_cases * 100.0) / total_cases;
        battery_pct = (total_cases == 0) ? 0.0 : (battery_cases * 100.0) / total_cases;
        grid_pct = (total_cases == 0) ? 0.0 : (grid_cases * 100.0) / total_cases;
        ac_pct = (total_cases == 0) ? 0.0 : (ac_cases * 100.0) / total_cases;
        fridge_pct = (total_cases == 0) ? 0.0 : (fridge_cases * 100.0) / total_cases;
        wm_pct = (total_cases == 0) ? 0.0 : (wm_cases * 100.0) / total_cases;
        fan_pct = (total_cases == 0) ? 0.0 : (fan_cases * 100.0) / total_cases;
        bulb_pct = (total_cases == 0) ? 0.0 : (bulb_cases * 100.0) / total_cases;

        $display("\n+-----------------------------------------------+");
        $display("| Mode      | Count | Percent |");
        $display("+-----------------------------------------------+");
        $display("| %-9s | %5d | %7.1f |", "Solar", solar_cases, solar_pct);
        $display("| %-9s | %5d | %7.1f |", "Battery", battery_cases, battery_pct);
        $display("| %-9s | %5d | %7.1f |", "Grid", grid_cases, grid_pct);
        $display("+-----------------------------------------------+");

        $display("\n+------------------------------------------------------------+");
        $display("| Appliance | Count | Percent |");
        $display("+------------------------------------------------------------+");
        $display("| %-9s | %5d | %7.1f |", "AC", ac_cases, ac_pct);
        $display("| %-9s | %5d | %7.1f |", "Fridge", fridge_cases, fridge_pct);
        $display("| %-9s | %5d | %7.1f |", "WM", wm_cases, wm_pct);
        $display("| %-9s | %5d | %7.1f |", "Fan", fan_cases, fan_pct);
        $display("| %-9s | %5d | %7.1f |", "Bulb", bulb_cases, bulb_pct);
        $display("+------------------------------------------------------------+\n");

        #20;
        $finish;
    end

endmodule