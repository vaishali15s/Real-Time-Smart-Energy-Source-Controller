module energy_fsm (
    input clk,
    input reset,

    input [15:0] load,
    input [15:0] solar,
    input [6:0] battery_soc,

    input [1:0] tariff_slot,   // 00=Night,01=Day,10=Peak

    // Fault Inputs
    input battery_overtemp,
    input solar_fault,
    input overload,
    input grid_fault,

    output reg solar_mode,
    output reg battery_mode,
    output reg grid_mode,
    output reg fault_mode,

    output reg [2:0] fault_code
);

    //====================================================
    // STATE ENCODING
    //====================================================
    parameter SOLAR   = 3'b000;
    parameter BATTERY = 3'b001;
    parameter GRID    = 3'b010;
    parameter FAULT   = 3'b011;

    reg [2:0] current_state, next_state;

    //====================================================
    // SOC THRESHOLDS
    //====================================================
    parameter SOC_LOW  = 7'd20;
    parameter SOC_HIGH = 7'd60;

    //====================================================
    // STATE REGISTER
    //====================================================
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= GRID;
        else
            current_state <= next_state;
    end

    //====================================================
    // NEXT STATE LOGIC
    //====================================================
    always @(*) begin

        next_state = current_state;

        //------------------------------------------------
        // HIGHEST PRIORITY = FAULT CHECK
        //------------------------------------------------
        if (battery_overtemp || overload ||
           (solar_fault && tariff_slot == 2'b01) ||
           (grid_fault  && current_state == GRID))
        begin
            next_state = FAULT;
        end

        else begin
            case(current_state)

            //--------------------------------------------
            // SOLAR MODE
            //--------------------------------------------
            SOLAR:
            begin
                if ((tariff_slot == 2'b00) || (solar < load)) begin
                    if (battery_soc > SOC_LOW)
                        next_state = BATTERY;
                    else
                        next_state = GRID;
                end
                else
                    next_state = SOLAR;
            end

            //--------------------------------------------
            // BATTERY MODE
            //--------------------------------------------
            BATTERY:
            begin
                if (battery_soc <= SOC_LOW)
                    next_state = GRID;

                else if ((tariff_slot == 2'b01) && (solar >= load))
                    next_state = SOLAR;

                else
                    next_state = BATTERY;
            end

            //--------------------------------------------
            // GRID MODE
            //--------------------------------------------
            GRID:
            begin
                // Peak tariff => prefer battery
                if (tariff_slot == 2'b10 && battery_soc > SOC_HIGH)
                    next_state = BATTERY;

                // Day + enough solar
                else if (tariff_slot == 2'b01 && solar >= load)
                    next_state = SOLAR;

                else
                    next_state = GRID;
            end

            //--------------------------------------------
            // FAULT MODE
            //--------------------------------------------
            FAULT:
            begin
                // Auto recover when all faults clear
                if (!(battery_overtemp || solar_fault || overload || grid_fault))
                    next_state = GRID;
                else
                    next_state = FAULT;
            end

            default:
                next_state = GRID;

            endcase
        end
    end

    //====================================================
    // OUTPUT LOGIC
    //====================================================
    always @(*) begin
        solar_mode   = 0;
        battery_mode = 0;
        grid_mode    = 0;
        fault_mode   = 0;
        fault_code   = 3'b000;

        case(current_state)

        //--------------------------------------------
        SOLAR:
            solar_mode = 1;

        //--------------------------------------------
        BATTERY:
            battery_mode = 1;

        //--------------------------------------------
        GRID:
            grid_mode = 1;

        //--------------------------------------------
        FAULT:
        begin
            fault_mode = 1;

            if (battery_overtemp)
                fault_code = 3'b001;
            else if (solar_fault)
                fault_code = 3'b010;
            else if (overload)
                fault_code = 3'b011;
            else if (grid_fault)
                fault_code = 3'b100;
            else
                fault_code = 3'b111;
        end

        endcase
    end

endmodule