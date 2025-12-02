`timescale 1ns / 1ps

module uart_tb;

    // Simulation Parameters
    // We use standard 100MHz Clock and 115200 Baud
    parameter CLK_FREQ  = 100_000_000; 
    parameter BAUD_RATE = 115200;      
    parameter DATA_WIDTH = 8;
    
    // 100MHz = 10ns Period
    parameter CLK_PERIOD = 10; 

    // Signals
    reg clk;
    reg reset;
    reg tx_start;
    reg [DATA_WIDTH-1:0] tx_data_in;
    wire tx_serial;
    wire tx_busy;
    wire [DATA_WIDTH-1:0] rx_data_out;
    wire rx_data_ready;
    wire rx_framing_error;

    // DUT Instantiation
    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .rx_serial(tx_serial), // Loopback TX to RX
        .rx_data_out(rx_data_out),
        .rx_data_ready(rx_data_ready),
        .rx_framing_error(rx_framing_error)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test Variables
    integer test_cnt = 0;
    integer fail_cnt = 0;

    // Monitor
    always @(posedge clk) begin
        if (rx_data_ready) begin
            $display("[%0t] Received: 0x%h", $time, rx_data_out);
        end
    end

    // Test Logic
    initial begin
        $dumpfile("uart_dump.vcd");
        $dumpvars(0, uart_tb);
        
        reset = 1;
        tx_start = 0;
        tx_data_in = 0;
        
        #(CLK_PERIOD * 10);
        reset = 0;
        #(CLK_PERIOD * 10);
        
        $display("Starting UART Test (Loopback)...");
        
        // Test 1: Send 0xA5
        send_byte(8'hA5);
        check_byte(8'hA5);
        
        // Test 2: Send 0x3C
        send_byte(8'h3C);
        check_byte(8'h3C);
        
        // Test 3: Send 0xFF
        send_byte(8'hFF);
        check_byte(8'hFF);

        if (fail_cnt == 0)
            $display("\nALL TESTS PASSED!");
        else
            $display("\nTESTS FAILED: %0d", fail_cnt);
            
        $finish;
    end
    
    // Tasks
    task send_byte;
        input [7:0] data;
        begin
            wait(!tx_busy);
            @(posedge clk);
            tx_data_in = data;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
        end
    endtask
    
    task check_byte;
        input [7:0] expected;
        begin
            // Wait for data ready with timeout
            fork : wait_block
                begin
                    wait(rx_data_ready);
                    if (rx_data_out !== expected) begin
                        $display("FAIL: Expected 0x%h, Got 0x%h", expected, rx_data_out);
                        fail_cnt = fail_cnt + 1;
                    end else begin
                        $display("PASS: Got 0x%h", rx_data_out);
                    end
                    disable timeout_block;
                end
                begin : timeout_block
                    // Wait enough time for one byte (approx 10 bits * 8680ns per bit ~ 86us)
                    #1000000; 
                    $display("FAIL: Timeout waiting for 0x%h", expected);
                    fail_cnt = fail_cnt + 1;
                    disable wait_block;
                end
            join
        end
    endtask

endmodule