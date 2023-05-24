//------------------------------------------------------------------------------
// File                     : top_tb.v
// Author                   : FFQ
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2022-04-14  FFQ       1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              :
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef CLK_FREQ
`define CLK_FREQ 50000000
`endif

module top_tb();

    //----------------------------------
    // Local Parameter Declarations
    //----------------------------------
    parameter                           SIZE_IN_BYTES = 1024;

    localparam                          CLK_FREQ = `CLK_FREQ;
    localparam                          CLK_PERIOD_HALF = 1000000000/(CLK_FREQ*2);

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    reg                                 PRESETn = 1'b0;
    reg                                 PCLK = 1'b0;
    reg                                 PSEL;
    reg [31:0]                          PADDR;
    reg                                 PENABLE;
    reg                                 PWRITE;
    reg [31:0]                          PWDATA;   
    wire [31:0]                         PRDATA;

    reg [31:0]                          reposit[0:1023];

    //----------------------------------
    // Start of Main Code
    //----------------------------------
    apb_sram #(
        .SIZE_IN_BYTES                  (SIZE_IN_BYTES)
    )
    u_apb_sram (
        .PRESETn                        (PRESETn),
        .PCLK                           (PCLK),
        .PSEL                           (PSEL),
        .PADDR                          (PADDR),
        .PENABLE                        (PENABLE),
        .PWRITE                         (PWRITE),
        .PWDATA                         (PWDATA),
        .PRDATA                         (PRDATA)
    );
    
    // generate PCLK
    always #CLK_PERIOD_HALF 
    begin
        PCLK <= ~PCLK;
    end 

    // generate PRESETn
    initial begin
        PRESETn <= 1'b0;
        repeat(5) @(posedge PCLK);
        PRESETn <= 1'b1;
    end

    // test memory
    initial begin
        PSEL = 1'b0;
        PADDR = ~32'h0;
        PENABLE = 1'b0;
        PWRITE = 1'b0;
        PWDATA = 32'hffff_ffff;
        wait(PRESETn == 1'b0);
        wait(PRESETn == 1'b1);
        repeat(3) @(posedge PCLK);
        memory_test(0, SIZE_IN_BYTES/4-1);
        repeat(5) @(posedge PCLK);
        $finish(2);
    end

    // memory test task
    task memory_test;
        // starting address
        input [31:0]                    start;
        // ending address, inclusive
        input [31:0]                    finish; 
        reg [31:0]                      dataW;
        reg [31:0]                      dataR;
        integer                         a; 
        integer                         b; 
        integer                         err;
    begin
        err = 0;
        // read-after-write test
        for (a = start; a <= finish; a = a + 1) begin
            dataW = $random;
            apb_write(4*a, dataW);
            apb_read (4*a, dataR);
            if (dataR !== dataW) begin
                err = err + 1;
                $display($time,,"%m Read after Write error at A:0x%08x D:0x%x, but 0x%x expected", a, dataR, dataW);
            end
        end
        if (err == 0) 
            $display($time,,"%m Read after Write 0x%x-%x test OK", start, finish);
        err = 0;
        // read_all-after-write_all test
        for (a = start; a <= finish; a = a + 1) begin
            b = a - start;
            reposit[b] = $random;
            apb_write(4*a, reposit[b]);
        end
        for (a = start; a <= finish; a = a + 1) begin
            b = a - start;
            apb_read(4*a, dataR);
            if (dataR !== reposit[b]) begin
                err = err + 1;
                $display($time,,"%m Read all after Write all error at A:0x%08x D:0x%x, but 0x%x expected", a, dataR, reposit[b]);
            end
        end
        if (err == 0) 
            $display($time,,"%m Read all after Write all 0x%x-%x test OK", start, finish);
    end
    endtask

    // APB write task
    task apb_write;
        input [31:0]                    addr;
        input [31:0]                    data;
    begin
        @(posedge PCLK);
        PADDR <= #1 addr;
        PWRITE <= #1 1'b1;
        PSEL <= #1 1'b1;
        PWDATA <= #1 data;
        @(posedge PCLK);
        PENABLE <= #1 1'b1;
        @(posedge PCLK);
        PSEL <= #1 1'b0;
        PENABLE <= #1 1'b0;
    end
    endtask

    // APB read task
    task apb_read;
        input [31:0]                     addr;
        output [31:0]                    data;
    begin
        @(posedge PCLK);
        PADDR <= #1 addr;
        PWRITE <= #1 1'b0;
        PSEL <= #1 1'b1;
        @(posedge PCLK);
        PENABLE <= #1 1'b1;
        @(posedge PCLK);
        PSEL <= #1 1'b0;
        PENABLE <= #1 1'b0;
        data = PRDATA; // it should be blocking
    end
    endtask

`ifdef VCS
    initial begin
        $fsdbDumpfile("top_tb.fsdb");
        $fsdbDumpvars;
    end

    initial begin
    `ifdef DUMP_VPD
        $vcdpluson();
    `endif
    end
`endif

endmodule
