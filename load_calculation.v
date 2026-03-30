module load_calculator (
    input ac_on,
    input fan_on,
    input wm_on,
    input bulb_on,
    input fridge_on,
    output reg [15:0] total_load
);

always @(*) begin
    total_load = 0;

    if (ac_on)      total_load = total_load + 1500;
    if (fan_on)     total_load = total_load + 100;
    if (wm_on)      total_load = total_load + 800;
    if (bulb_on)    total_load = total_load + 100;
    if (fridge_on)  total_load = total_load + 200;
end

endmodule