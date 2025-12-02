`timescale 1ns / 1ps

// ============================================================================
// Module: Baud Rate Generator (16x Oversampling)
// ============================================================================
module baud_rate_generator #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire reset,
    output reg tick // Generates a tick 16 times per bit
);
    // Calculate divisor for 16x oversampling
    // Example: 100MHz / (115200 * 16) = ~54 clocks per tick
    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);
    localparam integer COUNTER_WIDTH = $clog2(DIVISOR);
    
    reg [COUNTER_WIDTH-1:0] counter;
    
    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            tick <= 1'b0;
        end else begin
            if (counter >= DIVISOR - 1) begin
                counter <= 0;
                tick <= 1'b1;
            end else begin
                counter <= counter + 1;
                tick <= 1'b0;
            end
        end
    end
endmodule

// ============================================================================
// Module: UART Transmitter
// ============================================================================
module uart_tx #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset,
    input wire tick,    // 16x tick input
    input wire start,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg tx_serial,
    output reg busy
);

    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;
    
    reg [1:0] state, next_state;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [2:0] bit_counter;    
    reg [3:0] tick_counter;   
    
    // State Register
    always @(posedge clk) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end
    
    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = START;
            end
            START: begin
                // Wait for 16 ticks (entire start bit duration)
                if (tick && tick_counter == 15) next_state = DATA;
            end
            DATA: begin
                // Wait for 16 ticks per bit, for 8 bits
                if (tick && tick_counter == 15 && bit_counter == 7) next_state = STOP;
            end
            STOP: begin
                // Stop bit duration
                if (tick && tick_counter == 15) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath
    always @(posedge clk) begin
        if (reset) begin
            tx_serial <= 1'b1;
            busy <= 1'b0;
            data_reg <= 0;
            bit_counter <= 0;
            tick_counter <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    tx_serial <= 1'b1;
                    busy <= 1'b0;
                    tick_counter <= 0;
                    bit_counter <= 0;
                    if (start) begin
                        data_reg <= data_in;
                        busy <= 1'b1;
                    end
                end
                
                START: begin
                    tx_serial <= 1'b0; // Start bit
                    busy <= 1'b1;
                    if (tick) tick_counter <= tick_counter + 1;
                end
                
                DATA: begin
                    tx_serial <= data_reg[0]; // LSB First
                    busy <= 1'b1;
                    if (tick) begin
                        tick_counter <= tick_counter + 1;
                        if (tick_counter == 15) begin
                            data_reg <= {1'b0, data_reg[DATA_WIDTH-1:1]}; // Shift
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end
                
                STOP: begin
                    tx_serial <= 1'b1; // Stop bit
                    busy <= 1'b1;
                    if (tick) tick_counter <= tick_counter + 1;
                end
            endcase
        end
    end
endmodule

// ============================================================================
// Module: UART Receiver (FIXED SAMPLING)
// ============================================================================
module uart_rx #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset,
    input wire tick,      // 16x tick input
    input wire rx_serial,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_ready,
    output reg framing_error
);

    localparam [1:0] IDLE         = 2'b00,
                     START_DETECT = 2'b01,
                     DATA_RECEIVE = 2'b10,
                     STOP_CHECK   = 2'b11;
    
    reg [1:0] state, next_state;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [2:0] bit_counter;
    reg [3:0] sample_counter; 
    
    // Input Synchronization
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        if (reset) begin
            rx_sync1 <= 1'b1; rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_serial; rx_sync2 <= rx_sync1;
        end
    end
    
    // State Register
    always @(posedge clk) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end
    
    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!rx_sync2) next_state = START_DETECT;
            end
            START_DETECT: begin
                // Check middle of start bit (tick 7)
                if (tick && sample_counter == 7) begin
                    if (!rx_sync2) next_state = DATA_RECEIVE; 
                    else next_state = IDLE; 
                end
            end
            DATA_RECEIVE: begin
                // Wait for middle of last data bit
                if (tick && sample_counter == 15 && bit_counter == 7) next_state = STOP_CHECK;
            end
            STOP_CHECK: begin
                if (tick && sample_counter == 15) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 0;
            data_ready <= 0;
            framing_error <= 0;
            data_reg <= 0;
            bit_counter <= 0;
            sample_counter <= 0;
        end
        else begin
            data_ready <= 1'b0; // Default low
            
            case (state)
                IDLE: begin
                    bit_counter <= 0;
                    sample_counter <= 0;
                    framing_error <= 0;
                end
                
                START_DETECT: begin
                    if (tick) begin
                        if (sample_counter == 7) begin
                            // CRITICAL FIX: Reset counter so we wait exactly 16 ticks
                            // to reach the center of the first data bit.
                            sample_counter <= 0; 
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end
                end
                
                DATA_RECEIVE: begin
                    if (tick) begin
                        sample_counter <= sample_counter + 1;
                        if (sample_counter == 15) begin
                            // Sample the bit in the middle
                            data_reg <= {rx_sync2, data_reg[DATA_WIDTH-1:1]};
                            bit_counter <= bit_counter + 1;
                            // sample_counter wraps to 0 naturally (4-bit)
                        end
                    end
                end
                
                STOP_CHECK: begin
                    if (tick) begin
                        sample_counter <= sample_counter + 1;
                        if (sample_counter == 15) begin
                            if (rx_sync2 == 1'b1) begin
                                data_out <= data_reg;
                                data_ready <= 1'b1;
                            end else begin
                                framing_error <= 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule

// ============================================================================
// Module: UART Top
// ============================================================================
module uart_top #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset,
    input wire tx_start,
    input wire [DATA_WIDTH-1:0] tx_data_in,
    output wire tx_serial,
    output wire tx_busy,
    input wire rx_serial,
    output wire [DATA_WIDTH-1:0] rx_data_out,
    output wire rx_data_ready,
    output wire rx_framing_error
);

    wire tick; // 16x baud tick
    
    baud_rate_generator #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) baud_gen (
        .clk(clk), .reset(reset), .tick(tick)
    );
    
    uart_tx #(.DATA_WIDTH(DATA_WIDTH)) transmitter (
        .clk(clk), .reset(reset), .tick(tick),
        .start(tx_start), .data_in(tx_data_in),
        .tx_serial(tx_serial), .busy(tx_busy)
    );
    
    uart_rx #(.DATA_WIDTH(DATA_WIDTH)) receiver (
        .clk(clk), .reset(reset), .tick(tick),
        .rx_serial(rx_serial), .data_out(rx_data_out),
        .data_ready(rx_data_ready), .framing_error(rx_framing_error)
    );
endmodule