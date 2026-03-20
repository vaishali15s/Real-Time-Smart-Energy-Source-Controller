module solar_generation_calculator (
    input day_flag,
    input [15:0] solar_input,   
    output reg [15:0] solar_generation
);

always @(*) begin
    if (day_flag)
        solar_generation = solar_input; 
    else
        solar_generation = 0;
end

endmodule