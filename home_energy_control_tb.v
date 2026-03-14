
`timescale 1ns/1ps

module tb_home_energy_source_controller;

    reg clk;
    reg reset;
    reg ac_on, fan_on, wm_on, bulb_on, fridge_on;
    reg day_flag;
    reg battery_status;

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
        .solar_mode(solar_mode),
        .battery_mode(battery_mode),
        .grid_mode(grid_mode)
    );

    // Clock (even if currently unused)
    initial clk = 0;
    always #5 clk = ~clk;

    task run_case;
        input [8*40-1:0] name;
        input i_ac, i_fan, i_wm, i_bulb, i_fridge, i_day, i_batt;
        begin
            ac_on = i_ac;
            fan_on = i_fan;
            wm_on = i_wm;
            bulb_on = i_bulb;
            fridge_on = i_fridge;
            day_flag = i_day;
            battery_status = i_batt;

            #10; // wait for combinational settle

            // Basic validity checks
            if ((solar_mode === 1'bx) || (battery_mode === 1'bx) || (grid_mode === 1'bx))
                $display("ERROR [%0t] %0s -> X detected in outputs", $time, name);

            if ((solar_mode + battery_mode + grid_mode) != 1)
                $display("ERROR [%0t] %0s -> outputs not one-hot: S=%0b B=%0b G=%0b",
                         $time, name, solar_mode, battery_mode, grid_mode);

            $display("[%0t] %0s | day=%0b batt=%0b load=%0d solar_gen=%0d cost=%0d => S=%0b B=%0b G=%0b",
                     $time, name, day_flag, battery_status,
                     dut.total_load, dut.solar_generation, dut.cost,
                     solar_mode, battery_mode, grid_mode);
        end
    endtask

    initial begin
        // Init
        reset = 1;
        ac_on = 0; fan_on = 0; wm_on = 0; bulb_on = 0; fridge_on = 0;
        day_flag = 0; battery_status = 0;

        #12;
        reset = 0;

        // Test scenarios
        run_case("C1: Day, no load, battery off",     0,0,0,0,0,1,0);
        run_case("C2: Day, light load, battery off",  0,1,0,1,0,1,0);
        run_case("C3: Day, high load, battery on",    1,1,1,1,1,1,1);
        run_case("C4: Day, high load, battery off",   1,1,1,1,1,1,0);
        run_case("C5: Night, medium load, battery on",1,1,0,1,0,0,1);
        run_case("C6: Night, medium load, battery off",1,1,0,1,0,0,0);
        run_case("C7: Night, no load, battery on",    0,0,0,0,0,0,1);

        #20;
        $finish;
    end

endmodule
