module energy_consumption_calculator (
    input [15:0] total_load,
    output reg [15:0] energy_consumption,
    output reg [15:0] cost
);
parameter price_per_unit = 8; // Example price per unit energy

    always @(*) begin
        energy_consumption = total_load;
        cost = energy_consumption * price_per_unit;
    end

endmodule