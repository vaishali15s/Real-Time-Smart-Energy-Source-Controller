`timescale 1ns/1ps

module tb_home_energy_source_controller;

    reg clk;
    reg reset;
    reg ac_on, fan_on, wm_on, bulb_on, fridge_on;
    reg day_flag;
    reg battery_status;
    reg [2:0] case_id;

    // variable solar input
    reg [15:0] solar_input;

    wire solar_mode, battery_mode, grid_mode;

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
        .battery_status(battery_status),
        .solar_generation(solar_input),   // connect variable solar
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------
    // TASK: Run Test Case
    // -------------------------------
    task run_case;
        input [8*50-1:0] name;
        input [2:0] id;
        input i_ac, i_fan, i_wm, i_bulb, i_fridge, i_day, i_batt;
        input [15:0] solar_val;
        begin
            case_id = id;
            ac_on = i_ac;
            fan_on = i_fan;
            wm_on = i_wm;
            bulb_on = i_bulb;
            fridge_on = i_fridge;
            day_flag = i_day;
            battery_status = i_batt;
            solar_input = solar_val;

            // Wait for FSM to settle and produce outputs
            repeat(10) @(posedge clk);

            // Checks
            if ((solar_mode === 1'bx) || (battery_mode === 1'bx) || (grid_mode === 1'bx))
                $display("ERROR [%0t] %0s -> X detected", $time, name);

            if ((solar_mode + battery_mode + grid_mode) != 1)
                $display("ERROR [%0t] %0s -> not one-hot S=%0b B=%0b G=%0b",
                         $time, name, solar_mode, battery_mode, grid_mode);

            // Display
            $display("[%0t] %0s | day=%0b batt=%0b load=%0d solar=%0d => S=%0b B=%0b G=%0b",
                     $time, name, day_flag, battery_status,
                     dut.total_load, solar_input,
                     solar_mode, battery_mode, grid_mode);
        end
    endtask

    // -------------------------------
    // MAIN TEST
    // -------------------------------
    initial begin

        // Dump file
        $dumpfile("home_energy_control.vcd");
        $dumpvars(0, tb_home_energy_source_controller);

        // Dump FSM internals 
        $dumpvars(0, dut.current_state);
        $dumpvars(0, dut.next_state);
        $dumpvars(0, dut.counter);

        // Init
        reset = 1;
        ac_on = 0; fan_on = 0; wm_on = 0; bulb_on = 0; fridge_on = 0;
        day_flag = 0; battery_status = 0;
        solar_input = 0;

        #12;
        reset = 0;

        // -------------------------------
        // TEST CASES (WITH VARIABLE SOLAR)
        // -------------------------------

        run_case("C1: Day, no load, battery off",     1,0,0,0,0,0,1,0,16000);
        run_case("C2: Day, light load",               2,0,1,0,1,0,1,0,14000);
        run_case("C3: Day, high load, solar low",     3,1,1,1,1,1,1,1,2000);
        run_case("C4: Day, high load, no battery",    4,1,1,1,1,1,1,0,2000);
        run_case("C5: Night, medium load, battery",   5,1,1,0,1,0,0,1,0);
        run_case("C6: Night, medium load, no battery",6,1,1,0,1,0,0,0,0);
        run_case("C7: Day fluctuating solar",         7,1,0,0,1,1,1,1,10000);

        #50;
        $finish;
    end

    // -------------------------------
    // REAL-TIME MONITOR 
    // -------------------------------
    initial begin
        $monitor("Time=%0t | CS=%b NS=%b CNT=%d | S=%b B=%b G=%b",
                  $time,
                  dut.current_state,
                  dut.next_state,
                  dut.counter,
                  solar_mode, battery_mode, grid_mode);
    end

endmodule