module smart_load_manager(

input  ac_on,
input  fridge_on,
input  wm_on,
input  fan_on,
input  bulb_on,

input  [15:0] available_power,

output reg ac_supply,
output reg fridge_supply,
output reg wm_supply,
output reg fan_supply,
output reg bulb_supply,

output reg [15:0] final_load

);

always @(*) begin

    ac_supply     = 0;
    fridge_supply = 0;
    wm_supply     = 0;
    fan_supply    = 0;
    bulb_supply   = 0;

    final_load = 0;

    if (fridge_on) begin
        if (final_load + 200 <= available_power) begin
            fridge_supply = 1;
            final_load = final_load + 200;
        end
    end

    if (fan_on) begin
        if (final_load + 100 <= available_power) begin
            fan_supply = 1;
            final_load = final_load + 100;
        end
    end

    if (bulb_on) begin
        if (final_load + 100 <= available_power) begin
            bulb_supply = 1;
            final_load = final_load + 100;
        end
    end

    if (wm_on) begin
        if (final_load + 800 <= available_power) begin
            wm_supply = 1;
            final_load = final_load + 800;
        end
    end

    if (ac_on) begin
        if (final_load + 1500 <= available_power) begin
            ac_supply = 1;
            final_load = final_load + 1500;
        end
    end

end

endmodule