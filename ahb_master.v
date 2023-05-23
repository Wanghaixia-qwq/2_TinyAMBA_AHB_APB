// +FHDR----------------------------------------------------
//                   Copyright (c) 2023 
//                    ALL RIGHTS RESERVED
// ---------------------------------------------------------
// Filename         : ahb_master.v
// Author           : zj
// Creater On       : 2023-05-22 20:00
// Last Modifying   : 
// ---------------------------------------------------------
// Description      : 
//
//
// -FHDR----------------------------------------------------
module ahb_master(
    output                  hbusreq_o,
    output  [31:0]          haddr_o,
    output  [1:0]           htrans_o,
    output  [31:0]          hwdata_o,
    output                  hwrite_o,
    input                   hclk_i,
    input                   irst_n,
    input                   hgtant_i,
    input                   hready_i,
    input   [31:0]          hrdata_i,
    input                   we_i,
    input                   re_i
);

    reg     [1:0]           main_fsm_r;
    reg     [2:0]           rd_fsm_r;
    reg     [2:0]           wr_fsm_r;
    reg     [31:0]          haddr_r;
    reg     [1:0]           rd_cnt_r;
    reg     [31:0]          wr_cnt_r;

    parameter       data_size       = 4 ;
    parameter       rd_base_addr    = 'h1A00;
    parameter       wr_base_addr    = 'h1800;

    // The status of main fsm
    parameter       s0 = 'd0;
    parameter       s1 = 'd1;
    parameter       s2 = 'd2;

    // The status of read fsm
    parameter  RD_IDLE   = 3'b000;
    parameter  RD_BUSREQ = 3'b001;
    parameter  RD_ADDR   = 3'b010;
    parameter  RD_RD     = 3'b011;
    parameter  RD_LRD    = 3'b111;
   
    wire   fsm_rd_idle   = rd_fsm_r == RD_IDLE;
    wire   fsm_rd_busreq = rd_fsm_r == RD_BUSREQ;
    wire   fsm_rd_addr   = rd_fsm_r == RD_ADDR;
    wire   fsm_rd_rd     = rd_fsm_r == RD_RD;
    wire   fsm_rd_lrd    = rd_fsm_r == RD_LRD;
    wire   rd_last_data  = rd_cnt_r == data_size - 1'd1;
    
    //the status of write fsm
    parameter  WR_IDLE   = 3'b000;
    parameter  WR_BUSREQ = 3'b001;
    parameter  WR_ADDR   = 3'b010;
    parameter  WR_WD     = 3'b011;
    parameter  WR_LWD    = 3'b100;
    
    wire   fsm_wr_idle   = wr_fsm_r == WR_IDLE;
    wire   fsm_wr_busreq = wr_fsm_r == WR_BUSREQ;
    wire   fsm_wr_addr   = wr_fsm_r == WR_ADDR;
    wire   fsm_wr_wd     = wr_fsm_r == WR_WD;
    wire   fsm_wr_lwd    = wr_fsm_r == WR_LWD;
    wire   wr_last_data  = wr_cnt_r == data_size - 1'd1;

    wire        rd_done;
    wire        wr_done;
    reg         we_r,re_r;
    reg [1:0]   main_fsm_r;
    
    // Main FSM
    always  @(posedge hclk_i)
        if (~irst_n)
            main_fsm_r <= s0;
        else
            case(main_fsm_r)
                s0 : if (we_r | re_r)
                    main_fsm_r  <= s1;
                s1 : if (rd_done)
                    main_fsm_r  <= s2;
                s3 : if (wr_done)
                    main_fsm_r  <= s0;
                default: main_fsm_r <= s0;
            endcase

    // Sub Read FSM
    always  @(posedge hclk_i)
        if (~irst_n)
            rd_fsm_r    <= RD_IDLE;
        else
            case(rd_fsm_r)
                RD_IDLE : if((we_r | re_r) | rd_done)
                    rd_fsm_r    <= RD_BUSREQ;
                RD_BUSREQ : if(hgtand_i & hready_i)
                    rd_fsm_r    <= RD_ADDR;
                RD_ADDR : if(hready_i)
                    rd_fsm_r    <= RD_RD;
                RD_RD : if(rd_cnt_r == data_size - 2 & hready_i)
                    rd_fsm_r    <= RD_LRD;
                RD_LRD : if (hready_i & rd_last_data)
                    rd_fsm_r    <= RD_IDLE;
                default:    rd_fsm_r <= RD_DILE;
            endcase

    //Sub Write FSM
    always @(posedge hclk_i)
        if (~irst_n)
            wr_fsm_r <= WR_IDLE;
        else
            case(wr_fsm_r)
                WR_IDLE : if (rd_done)
                wr_fsm_r <= WR_BUSREQ;
                WR_BUSREQ : if (hgrant_i & hready_i)
                wr_fsm_r <= WR_ADDR;
                WR_ADDR : if (hready_i)
                wr_fsm_r <= WR_WD;
                WR_WD : if (wr_cnt_r == data_size-2 & hready_i)
                wr_fsm_r <= WR_LWD;
                WR_LWD : if (hready_i & wr_last_data)
                wr_fsm_r <= WR_IDLE;
                default:
                wr_fsm_r <= WR_IDLE;
            endcase
    //we_r
    always @(posedge hclk_i)
        if (~irst_n | we_r)
            we_r <= 1'b0;
        else(we_i)
            we_r <= 1'b1;
    
    //re_r
    always @(posedge hclk_i)
        if (~irst_n | re_r)
            re_r <= 1'b0;
        else(re_i)
            re_r <= 1'b1;

    assign rd_done = main_fsm_r == s1 & hready_i & rd_last_data;
    
    assign wr_done = main_fsm_r == s2 & hready_i & wr_last_data;
    
    assign hwrite_o = (main_fsm_r == s2) ? 'd1 : 'd0;
    
    assign  hbusreq_o = (fsm_rd_busreq || fsm_wr_busreq) ? 'd1 : 'd0;
    
    //rd_done_r
    always @(posedge hclk_i)
        if (~irst_n || rd_done_r)
            rd_done_r <= 'd0;
        else if (rd_done)
            rd_done_r <= 'd1;
    
    //wr_done_r
    always @(posedge hclk_i)
        if (~irst_n || wr_done_r)
            wr_done_r <= 'd0;
        else if (wr_done)
            wr_done_r <= 'd1;
    
    assign  htrans_o = (fsm_rd_addr || fsm_wr_addr) ? 2'b10 : 2'b11;
    wire  addr_add_en = (main_fsm_r == s1 || main_fsm_r == s2) &&
                        (fsm_rd_addr || fsm_rd_rd || fsm_wr_addr || fsm_wr_wd);
    
    //haddr_r  准备输出的地址总线
    always @(posedge hclk_i)
        if (~irst_n)
            haddr_r <= 32'd0;
        else if (main_fsm_r == S1 & fsm_rd_busreq & hready_i)
            haddr_r <= rd_base_addr;
        else if (main_fsm_r == S2 & fsm_wr_busreq & hready_i)
            haddr_r <= wr_base_addr;
        else if (addr_add_en)
            haddr_r <= haddr_r + 32'd4;
    
    
    //rd_cnt_r
    always @(posedge hclk_i)
        if (~irst_n)
            rd_cnt_r <= 3'd0;
        else if (hready_i & fsm_rd_addr)
            rd_cnt_r <= 3'd0;
        else if (hready_i & fsm_rd_rd)
            rd_cnt_r <= rd_cnt_r + 1'd1;
        else if (hready_i & rd_last_data)
            rd_cnt_r <= 3'd0;
    
    //wr_cnt_r
    always @(posedge hclk_i)
        if (~irst_n)
            wr_cnt_r <= 3'd0;
        else if (hready_i & fsm_wr_addr)
            wr_cnt_r <= 3'd0;
        else if (hready_i & fsm_wr_wd)
            wr_cnt_r <= wr_cnt_r + 1'd1;
        else if (hready_i & wr_last_data)
            wr_cnt_r <= 3'd0;
    
    reg  [31:0] rd_data_r [0 : data_size-1];

    always @(posedge hclk_i)
        if (~irst_n)
            {rd_data_r[0],rd_data_r[1],rd_data_r[2],rd_data_r[3]} <= 32'd0;
        else if (main_fsm_r == s1 & (fsm_rd_rd || fsm_rd_lrd) & hready_i)
            rd_data_r <= hrdata_i;
    
    // 输出的数据总线 和 地址总线
    assign  hwdata_o = (main_fsm_r == s2 & (fsm_wr_wd || fsm_wr_lwd) & hready_i) ? rd_data_r[wr_cnt_r] : 32'b0;
    assign  haddr_o  = haddr_r;
    
endmodule
