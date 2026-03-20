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
    // 2. Registers
    // -------------------------------
    reg [1:0] current_state, next_state;
    reg [1:0] target_state;              // store the next stable state during transition
    reg [1:0] next_state_decision;       

    // -------------------------------
    // 3. Counter
    // -------------------------------
    reg [3:0] counter;
    parameter DELAY = 4'd5;

    // -------------------------------
    // 4. State Register
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= GRID;
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
    // 6. Decision Logic (Combinational)
    // -------------------------------
    always @(*) begin
        case (current_state)

            SOLAR: begin
                if (!day_flag)
                    next_state_decision = (battery_status) ? BATTERY : GRID;
                else if (solar < load)
                    next_state_decision = (battery_status) ? BATTERY : GRID;
                else
                    next_state_decision = SOLAR;
            end

            BATTERY: begin
                if (day_flag && solar >= load)
                    next_state_decision = SOLAR;
                else if (!battery_status)
                    next_state_decision = GRID;
                else
                    next_state_decision = BATTERY;
            end

            GRID: begin
                if (day_flag && solar >= load)
                    next_state_decision = SOLAR;
                else if (battery_status)
                    next_state_decision = BATTERY;
                else
                    next_state_decision = GRID;
            end

            default:
                next_state_decision = GRID;

        endcase
    end

    // -------------------------------
    // 7. Store target_state 
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            target_state <= GRID;
        else if (current_state != TRANSITION)
            target_state <= next_state_decision;
    end

    // -------------------------------
    // 8. Next-State Logic
    // -------------------------------
    always @(*) begin
        next_state = current_state;

        case (current_state)

            SOLAR, BATTERY, GRID: begin
                if (next_state_decision != current_state)
                    next_state = TRANSITION;
            end

            TRANSITION: begin
                if (counter >= DELAY)
                    next_state = target_state;  
                else
                    next_state = TRANSITION;
            end

        endcase
    end

    // -------------------------------
    // 9. Output Logic (Moore FSM)
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