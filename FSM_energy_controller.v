module energy_fsm (
    input clk,
    input reset,
    input [15:0] load,
    input [15:0] solar,
    input day_flag,
    input [6:0] battery_soc,

    output reg solar_mode,
    output reg battery_mode,
    output reg grid_mode
);

    // STATES
    parameter SOLAR      = 2'b00;
    parameter BATTERY    = 2'b01;
    parameter GRID       = 2'b10;
    parameter TRANSITION = 2'b11;

    // SOC LIMITS
    parameter SOC_LOW  = 7'd20;
    parameter SOC_HIGH = 7'd80;

    reg [1:0] current_state, next_state;
    reg [1:0] target_state;

    // Transition delay
    reg [3:0] counter;
    parameter DELAY = 4'd5;

    // STATE REGISTER
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= GRID;
        else
            current_state <= next_state;
    end

    // COUNTER
    always @(posedge clk or posedge reset) begin
        if (reset)
            counter <= 0;
        else if (current_state == TRANSITION)
            counter <= counter + 1;
        else
            counter <= 0;
    end

    // TARGET STATE LOGIC
    always @(*) begin
        case (current_state)

            SOLAR: begin
                if (!day_flag || solar < load)
                    target_state = (battery_soc > SOC_LOW) ? BATTERY : GRID;
                else
                    target_state = SOLAR;
            end

            BATTERY: begin
                if (day_flag && solar >= load)
                    target_state = SOLAR;
                else if (battery_soc <= SOC_LOW)
                    target_state = GRID;
                else
                    target_state = BATTERY;
            end

            GRID: begin
                if (day_flag && solar >= load)
                    target_state = SOLAR;
                else if (battery_soc > SOC_LOW)   // ✅ FIXED
                    target_state = BATTERY;
                else
                    target_state = GRID;
            end

            TRANSITION: begin
                target_state = target_state; // hold
            end

            default: target_state = GRID;
        endcase
    end

    // NEXT STATE LOGIC
    always @(*) begin
        case (current_state)

            TRANSITION: begin
                if (counter >= DELAY)
                    next_state = target_state;   // ✅ FIXED CORE BUG
                else
                    next_state = TRANSITION;
            end

            default: begin
                if (target_state != current_state)
                    next_state = TRANSITION;
                else
                    next_state = current_state;
            end

        endcase
    end

    // OUTPUT LOGIC (MOORE)
    always @(*) begin
        solar_mode = 0;
        battery_mode = 0;
        grid_mode = 0;

        case (current_state)
            SOLAR:   solar_mode = 1;
            BATTERY: battery_mode = 1;
            GRID:    grid_mode = 1;
        endcase
    end

endmodule