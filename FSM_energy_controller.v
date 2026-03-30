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

    // -------------------------------
    // 1. State Encoding
    // -------------------------------
    parameter SOLAR      = 2'b00;
    parameter BATTERY    = 2'b01;
    parameter GRID       = 2'b10;
    parameter TRANSITION = 2'b11;

    // -------------------------------
    // 2. SOC Thresholds
    // -------------------------------
    parameter SOC_LOW  = 7'd20;
    parameter SOC_HIGH = 7'd80;

    // -------------------------------
    // 3. State Registers
    // -------------------------------
    reg [1:0] current_state, next_state;
    reg [1:0] target_state;

    // -------------------------------
    // 4. Transition Counter
    // -------------------------------
    reg [3:0] counter;
    parameter DELAY = 4'd5;

    // -------------------------------
    // 5. State Register
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= GRID;
        else
            current_state <= next_state;
    end

    // -------------------------------
    // 6. Counter Logic
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            counter <= 0;
        else if (current_state == TRANSITION)
            counter <= counter + 1;
        else
            counter <= 0;
    end

    // -------------------------------
    // 7. Next-State Logic
    // -------------------------------
    always @(*) begin
        next_state = current_state;
        target_state = current_state;

        case (current_state)

            // -------- SOLAR --------
            SOLAR: begin
                if (!day_flag)
                    target_state = (battery_soc > SOC_LOW) ? BATTERY : GRID;
                else if (solar < load)
                    target_state = (battery_soc > SOC_LOW) ? BATTERY : GRID;
                else
                    target_state = SOLAR;

                if (target_state != SOLAR)
                    next_state = TRANSITION;
            end

            // -------- BATTERY --------
            BATTERY: begin
                if (day_flag && solar >= load)
                    target_state = SOLAR;
                else if (battery_soc <= SOC_LOW)
                    target_state = GRID;
                else
                    target_state = BATTERY;

                if (target_state != BATTERY)
                    next_state = TRANSITION;
            end

            // -------- GRID --------
            GRID: begin
                if (day_flag && solar >= load)
                    target_state = SOLAR;
                else if (battery_soc > SOC_HIGH)
                    target_state = BATTERY;
                else
                    target_state = GRID;

                if (target_state != GRID)
                    next_state = TRANSITION;
            end

            // -------- TRANSITION --------
            TRANSITION: begin
                if (counter >= DELAY) begin
                    if (day_flag && solar >= load)
                        next_state = SOLAR;
                    else if (battery_soc > SOC_LOW)
                        next_state = BATTERY;
                    else
                        next_state = GRID;
                end
                else
                    next_state = TRANSITION;
            end

        endcase
    end

    // -------------------------------
    // 8. Output Logic (Moore)
    // -------------------------------
    always @(*) begin
        solar_mode = 0;
        battery_mode = 0;
        grid_mode = 0;

        case (current_state)
            SOLAR:      solar_mode = 1;
            BATTERY:    battery_mode = 1;
            GRID:       grid_mode = 1;
            TRANSITION: begin
                solar_mode = 0;
                battery_mode = 0;
                grid_mode = 0;
            end
        endcase
    end

endmodule