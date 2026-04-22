module battery_soc_controller (
    input clk,
    input reset,
    input [15:0] load,
    input [15:0] solar,
    input battery_mode,

    output reg [6:0] battery_soc   // Range: 0-100
);

    parameter STEP_CHARGE = 2;
    parameter STEP_DISCHARGE = 1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            battery_soc <= 7'd50;   // Initial SOC = 50%
        end
        else begin
            if (solar > load) begin
                if (battery_soc < 100)
                    battery_soc <= battery_soc + STEP_CHARGE;
                else
                    battery_soc <= 7'd100;
            end
            else if (battery_mode) begin
                if (battery_soc > 0)
                    battery_soc <= battery_soc - STEP_DISCHARGE;
                else
                    battery_soc <= 7'd0;
            end
            else begin
                battery_soc <= battery_soc;
            end
        end
    end

endmodule