module load_calculator (
    input ac_on,
    input wm_on,
    input fan_on,
    input bulb_on,
    input fridge_on,
    output reg [15:0] total_load
);
    always @(*) begin
        total_load = 0;
        if (ac_on) total_load = total_load + 1500; // Example load for AC
        if (wm_on) total_load = total_load + 500; // Example load for Washing Machine
        if (fan_on) total_load = total_load + 200; // Example load for Fan
        if (bulb_on) total_load = total_load + 100; // Example load for Bulb
        if (fridge_on) total_load = total_load + 300; // Example load for Fridge
        
    end
endmodule