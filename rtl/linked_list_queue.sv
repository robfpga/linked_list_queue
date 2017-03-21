//========================================================================== //
// Copyright (c) 2016, Stephen Henry
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//========================================================================== //

`include "pd_pkg.vh"

module linked_list_queue #(
parameter int W = 32,
parameter int CTXT = 16,
parameter int M = 128
)
(
   //======================================================================== //
   //                                                                         //
   // Misc.                                                                   //
   //                                                                         //
   //======================================================================== //

   //
     input                                        clk
   , input                                        rst

   //======================================================================== //
   //                                                                         //
   // Command Interface                                                       //
   //                                                                         //
   //======================================================================== //

   , input                                        cmd_pass
   , input                                        cmd_push
   , input        [W-1:0]                         cmd_data
   , input        [$clog2(CTXT)-1:0]              cmd_ctxt
   //
   , output logic                                 cmd_accept

   //======================================================================== //
   //                                                                         //
   // Response Interface                                                      //
   //                                                                         //
   //======================================================================== //

   , output logic                                 resp_pass_r
   , output logic                                 resp_empty_fault_r
   , output logic [W-1:0]                         resp_data_w

   //======================================================================== //
   //                                                                         //
   // Status Interface                                                        //
   //                                                                         //
   //======================================================================== //

   , output logic                                 full_r
   , output logic [CTXT-1:0]                      empty_r
   , output logic                                 busy_r
);

  localparam int RAM_LATENCY = 1;

  typedef struct packed {
    logic        pass;
    logic        empty_fault;
  } ucode_t;
  localparam int UCODE_W = $bits(ucode_t);

  // ======================================================================== //
  //                                                                          //
  // Wires                                                                    //
  //                                                                          //
  // ======================================================================== //

  `SPSRAM_SIGNALS(data_table_, W, $clog2(M));
  //
  logic                            lkup_pass_r;
  logic                            lkup_rnw_r;
  logic [W-1:0]                    lkup_data_r;
  logic [$clog2(M)-1:0]            lkup_addr_r;
  logic                            lkup_empty_fault_r;
  //
  ucode_t                          ucode_in_w;
  ucode_t                          ucode_out_r;

  // ======================================================================== //
  //                                                                          //
  // Combinatorial Logic                                                      //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : data_table_PROC

      //
      data_table_en           = lkup_pass_r;
      data_table_wen          = (~lkup_rnw_r);
      data_table_addr         = lkup_addr_r;
      data_table_din          = lkup_data_r;

      //
      ucode_in_w              = '0;
      ucode_in_w.pass         = lkup_pass_r;
      ucode_in_w.empty_fault  = lkup_empty_fault_r;

      //
      resp_pass_r             = ucode_out_r.pass;
      resp_empty_fault_r      = ucode_out_r.empty_fault;

    end // block: data_table_PROC

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  delay_pipe #(.W(UCODE_W), .N(RAM_LATENCY)) u_egress_pipe (
    //
      .clk                    (clk                )
    , .rst                    (rst                )
    //
    , .in                     (ucode_in_w         )
    , .out_r                  (ucode_out_r        )
  );

  // ------------------------------------------------------------------------ //
  //
  linked_list_queue_cntrl #(.W(W), .CTXT(CTXT), .M(M)) u_cntrl (
    //
      .clk                    (clk                )
    , .rst                    (rst                )
    //
    , .cmd_pass               (cmd_pass           )
    , .cmd_push               (cmd_push           )
    , .cmd_data               (cmd_data           )
    , .cmd_ctxt               (cmd_ctxt           )
    , .cmd_accept             (cmd_accept         )
    //
    , .lkup_pass_r            (lkup_pass_r        )
    , .lkup_rnw_r             (lkup_rnw_r         )
    , .lkup_data_r            (lkup_data_r        )
    , .lkup_addr_r            (lkup_addr_r        )
    , .lkup_empty_fault_r     (lkup_empty_fault_r )
    //
    , .full_r                 (full_r             )
    , .empty_r                (empty_r            )
    , .busy_r                 (busy_r             )
  );

  // ------------------------------------------------------------------------ //
  //
  spsram #(.W(W), .N(M)) u_data_table (
      .clk                    (clk                )
    , .en                     (data_table_en      )
    , .wen                    (data_table_wen     )
    , .addr                   (data_table_addr    )
    , .din                    (data_table_din     )
    , .dout                   (resp_data_w        )
  );

endmodule // linked_list_fifo
