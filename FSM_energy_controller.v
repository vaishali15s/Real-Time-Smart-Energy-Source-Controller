module energy_fsm (
    input clk,
    input reset,
    input [15:0] load,
    input [15:0] solar,
    input battery_status,
    input day_flag,

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
    // 2. State Registers
    // -------------------------------
    reg [1:0] current_state, next_state, target_state;

    // -------------------------------
    // 3. Counter for Transition Delay
    // -------------------------------
    reg [3:0] counter;
    parameter DELAY = 4'd5;

    // -------------------------------
    // 4. State Register (Memory)
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= GRID;   // safe start
        else
            current_state <= next_state;
    end

    // -------------------------------
    // 5. Counter Logic
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
    // 6. Next-State Logic
    // -------------------------------
    always @(*) begin
        next_state = current_state;   // default
        target_state = current_state; // default

        case (current_state)

            // -------- SOLAR STATE --------
            SOLAR: begin
                if (!day_flag)
                    target_state = (battery_status) ? BATTERY : GRID;
                else if (solar < load)
                    target_state = (battery_status) ? BATTERY : GRID;
                else
                    target_state = SOLAR;

                if (target_state != SOLAR)
                    next_state = TRANSITION;
            end

            // -------- BATTERY STATE --------
            BATTERY: begin
                if (day_flag && solar >= load)
                    target_state = SOLAR;
                else if (!battery_status)
                    target_state = GRID;
                else
                    target_state = BATTERY;

                if (target_state != BATTERY)
                    next_state = TRANSITION;
            end

            // -------- GRID STATE --------
            GRID: begin
                if (day_flag && solar >= load)
                    target_state = SOLAR;
                else if (battery_status)
                    target_state = BATTERY;
                else
                    target_state = GRID;

                if (target_state != GRID)
                    next_state = TRANSITION;
            end

            // -------- TRANSITION STATE --------
            TRANSITION: begin
                if (counter >= DELAY)
                    next_state = target_state;
                else
                    next_state = TRANSITION;
            end

        endcase
    end

    // -------------------------------
    // 7. Output Logic (Moore FSM)
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