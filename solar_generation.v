module solar_generation_calculator (
    input day_flag,
    output reg [15:0] solar_generation
);

always @(*) begin
    if (day_flag)
        solar_generation = 14000; // realistic solar (10–16 kW)
    else
        solar_generation = 0;
end

endmodule