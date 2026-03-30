`timescale 1ns/1ps

module tb_home_energy_source_controller;

    reg clk;
    reg reset;
    reg ac_on, fan_on, wm_on, bulb_on, fridge_on;
    reg day_flag;

    // ✅ Proper SOC (0–100)
    reg [6:0] battery_soc;

    // ✅ Variable solar input (in watts)
    reg [15:0] solar_input;

    wire solar_mode, battery_mode, grid_mode;

    // ================================
    // DUT
    // ================================
    home_energy_source_controller dut (
        .clk(clk),
        .reset(reset),
        .ac_on(ac_on),
        .fan_on(fan_on),
        .wm_on(wm_on),
        .bulb_on(bulb_on),
        .fridge_on(fridge_on),
        .day_flag(day_flag),
        .battery_soc(battery_soc),
        .solar_generation(solar_input),   // ✅ external solar control
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode)
    );

    // ================================
    // CLOCK
    // ================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ================================
    // TASK: RUN TEST CASE
    // ================================
    task run_case;
        input [8*60-1:0] name;
        input i_ac, i_fan, i_wm, i_bulb, i_fridge;
        input i_day;
        input [6:0] soc;
        input [15:0] solar_val;

        begin
            ac_on = i_ac;
            fan_on = i_fan;
            wm_on = i_wm;
            bulb_on = i_bulb;
            fridge_on = i_fridge;
            day_flag = i_day;
            battery_soc = soc;
            solar_input = solar_val;

            // Wait for FSM to stabilize
            repeat(10) @(posedge clk);

            // ================================
            // ERROR CHECKS
            // ================================
            if ((solar_mode === 1'bx) || (battery_mode === 1'bx) || (grid_mode === 1'bx))
                $display("❌ ERROR [%0t] %0s -> X detected", $time, name);

            if ((solar_mode + battery_mode + grid_mode) > 1)
                $display("❌ ERROR [%0t] %0s -> multiple outputs active", $time, name);

            // ================================
            // DISPLAY
            // ================================
            $display("[%0t] %0s | Day=%0b SOC=%0d%% Load=%0d Solar=%0d => S=%0b B=%0b G=%0b",
                     $time, name, day_flag, battery_soc,
                     dut.total_load, solar_input,
                     solar_mode, battery_mode, grid_mode);
        end
    endtask

    // ================================
    // MAIN TEST
    // ================================
    initial begin

        // Dump for GTKWave
        $dumpfile("home_energy_control.vcd");
        $dumpvars(0, tb_home_energy_source_controller);

        // INIT
        reset = 1;
        ac_on = 0; fan_on = 0; wm_on = 0; bulb_on = 0; fridge_on = 0;
        day_flag = 0;
        battery_soc = 50;
        solar_input = 0;

        #12;
        reset = 0;

        // ================================
        // TEST CASES (REALISTIC)
        // ================================

        // 🟢 Day, no load
        run_case("C1: Day, no load", 
                 0,0,0,0,0, 1, 50, 16000);

        // 🟢 Day, light load, good solar
        run_case("C2: Day, light load", 
                 0,1,0,1,0, 1, 40, 14000);

        // 🟡 Day, high load, strong battery
        run_case("C3: Day, high load, strong battery", 
                 1,1,1,1,1, 1, 80, 2000);

        // 🔴 Day, high load, weak battery
        run_case("C4: Day, high load, weak battery", 
                 1,1,1,1,1, 1, 10, 2000);

        // 🔵 Night, medium load, good battery
        run_case("C5: Night, medium load, good battery", 
                 1,1,0,1,0, 0, 60, 0);

        // 🔴 Night, medium load, low battery
        run_case("C6: Night, medium load, low battery", 
                 1,1,0,1,0, 0, 10, 0);

        // 🟢 Day, fluctuating solar
        run_case("C7: Day, fluctuating solar", 
                 1,0,0,1,1, 1, 50, 10000);

        // ⚠ Edge case: zero load
        run_case("C8: Zero load edge case", 
                 0,0,0,0,0, 1, 70, 5000);

        #50;
        $finish;
    end

    // ================================
    // REAL-TIME MONITOR
    // ================================
    initial begin
        $monitor("Time=%0t | State S=%b B=%b G=%b",
                  $time, solar_mode, battery_mode, grid_mode);
    end

endmodule