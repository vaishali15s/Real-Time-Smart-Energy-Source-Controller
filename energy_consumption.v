module energy_consumption_calculator (
    input [15:0] total_load,
    output reg [15:0] energy_consumption,
    output reg [15:0] cost
);

always @(*) begin
    energy_consumption = total_load;
    cost = total_load * 8; // ₹8 per unit
end

endmodule