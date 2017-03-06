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

module linked_list_queue_cntrl #(

   // Data Width
   //
     parameter int W = 32

   // Number of FIFO Contexts (CTXT)
   //
   , parameter int CTXT = 16

   // Number of LINK entries in main Linked-List Table.
   //
   , parameter int M = 128
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
   // Lookup Interface                                                        //
   //                                                                         //
   //======================================================================== //

   , output logic                                 lkup_pass_r
   , output logic                                 lkup_rnw_r
   , output logic [W-1:0]                         lkup_data_r
   , output logic [$clog2(M)-1:0]                 lkup_addr_r
   , output logic                                 lkup_empty_fault_r

   //======================================================================== //
   //                                                                         //
   // Status Interface                                                        //
   //                                                                         //
   //======================================================================== //

   , output logic                                 full_r
   , output logic [CTXT-1:0]                      empty_r
   , output logic                                 busy_r
);

  `define ENCODE_W M
  `define ENCODE_SUFFIX M
  `include "encode.vh"
  `undef ENCODE_W
  `undef ENCODE_SUFFIX

  `define FFS_W M
  `define FFS_SUFFIX M
  `include "ffs.vh"
  `undef ENCODE_W
  `undef ENCODE_SUFFIX

  // ======================================================================== //
  //                                                                          //
  // Typedefs                                                                 //
  //                                                                          //
  // ======================================================================== //

  typedef logic [CTXT-1:0] n_t;
  typedef logic [M-1:0] m_t;
  //
  localparam int CTXT_W = $clog2(CTXT);
  typedef logic [CTXT_W-1:0] ctxt_t;
  //
  localparam int WORD_W = W;
  typedef logic [WORD_W-1:0] w_t;
  //
  localparam int ADDR_W  = $clog2(M);
  typedef logic [ADDR_W-1:0] addr_t;

  //
  typedef struct packed {
    logic        empty;
    addr_t       head;
    addr_t       tail;
  } state_t;
  localparam int STATE_W = $bits(state_t);

  //
  typedef struct packed {
    // Constants:
    logic        push;
    ctxt_t       ctxt;
    w_t          data;
    // Forwarded:
    state_t      state;
    // Temporaries:
    addr_t       link;
    logic        empty_fault;
    logic        tail_valid;
  } ucode_t;
  localparam int UCODE_W  = $bits(ucode_t);

  typedef enum   logic [2:0] { INIT_RESET  = 3'b1_0_0,
                               INIT_EXE    = 3'b1_1_1,
                               INIT_DONE   = 3'b0_0_1
                             } fsm_init_t;
  localparam int INIT_WRITE_B = 1;
  localparam int INIT_BUSY_B = 2;

  typedef struct packed {
    ctxt_t       ctxt;
  } fsm_init_state_t;

  // ======================================================================== //
  //                                                                          //
  // Wires                                                                    //
  //                                                                          //
  // ======================================================================== //

  //
  `DPSRAM_SIGNALS(state_table_, STATE_W, $clog2(CTXT));
  `SPSRAM_SIGNALS(queue_table_, ADDR_W, $clog2(M));

  //
  logic                       state_table_collision;
  //
  ucode_t                     ucode_s0_w;
  ucode_t                     ucode_s0_r;
  logic                       ucode_s0_en;
  //
  ucode_t                     ucode_s1_w;
  ucode_t                     ucode_s1_r;
  logic                       ucode_s1_en;
  //
  ucode_t                     ucode_s2_w;
  ucode_t                     ucode_s2_r;
  logic                       ucode_s2_en;
  //
  ucode_t                     ucode_s3_w;
  ucode_t                     ucode_s3_r;
  logic                       ucode_s3_en;
  //
  ucode_t                     ucode_s4_w;
  ucode_t                     ucode_s4_r;
  logic                       ucode_s4_en;
  //
  logic                       state_s5_en;
  state_t                     state_s5_w;
  state_t                     state_s5_r;
  ctxt_t                      ctxt_s5_w;
  ctxt_t                      ctxt_s5_r;
  //
  logic                       valid_s0_w;
  logic                       valid_s0_r;
  //
  logic                       valid_s1_w;
  logic                       valid_s1_r;
  //
  logic                       valid_s2_w;
  logic                       valid_s2_r;
  //
  logic                       valid_s3_w;
  logic                       valid_s3_r;
  //
  logic                       valid_s4_w;
  logic                       valid_s4_r;
  //
  logic                       valid_s5_w;
  logic                       valid_s5_r;
  //
  logic                       s0_hazard;
  logic                       stall_s0;
  logic                       adv_s0;
  //
  logic                       full_w;
  n_t                         empty_w;
  //
  state_t                     state_s1_fwd;
  state_t                     state_s2_fwd;
  state_t                     state_s2_fwd_no_qt;
  state_t                     state_s3_fwd;
  //
  logic                       fp_alloc;
  addr_t                      fp_alloc_id;
  logic                       fp_clear;
  addr_t                      fp_clear_id;
  m_t                         fp_state_r;
  logic                       fp_all_alloc_w;
  //
  logic                       cmd_adv;
  //
  state_t                     state_s3_next;
  state_t                     state_s4_next;
  //
  logic                       lkup_pass_w;
  logic                       lkup_rnw_w;
  w_t                         lkup_data_w;
  addr_t                      lkup_addr_w;
  logic                       lkup_empty_fault_w;
  logic                       lkup_en;
  //
  fsm_init_t                  fsm_init_r;
  fsm_init_t                  fsm_init_w;
  logic                       fsm_init_en;
  //
  fsm_init_state_t            fsm_init_state_r;
  fsm_init_state_t            fsm_init_state_w;
  logic                       fsm_init_state_en;

  // ======================================================================== //
  //                                                                          //
  // Combinatorial Logic                                                      //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : fp_PROC

      //
      fp_alloc     = (cmd_pass & cmd_accept & cmd_push);
      fp_alloc_id  = EncodeM(FFSM(~fp_state_r));

      //
      fp_clear     = valid_s4_r & (~ucode_s4_r.push);
      fp_clear_id  = ucode_s4_r.link;

    end // block: fp_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : exe_PROC

      //
      state_s3_next  = state_s2_fwd;

      //
      case ({ucode_s2_r.push, state_s2_fwd.empty})
        2'b1_0:
          state_s3_next.head  = ucode_s2_r.link;
        2'b1_1: begin
          state_s3_next.head  = ucode_s2_r.link;
          state_s3_next.tail  = ucode_s2_r.link;
        end
        default:
          state_s3_next.tail  = state_s3_next.tail;
      endcase // case ({ucode_s2_r.push, state_s2_fwd})

      //
      case ({ucode_s2_r.push})
        1'b1:
          state_s3_next.empty  = '0;
        default: begin
          //state_t s = ucode_s2_r.state; // TODO: should be forwarded version
          state_s3_next.empty  = (state_s2_fwd.tail == state_s2_fwd.head);
        end
      endcase // case ({ucode_s2_r.push})

      //
      state_s4_next  = ucode_s3_r.state;

      //
      case ({ucode_s3_r.tail_valid, ucode_s3_r.push})
        2'b0_0:  state_s4_next.tail  = queue_table_dout;
        2'b0_1:  state_s4_next.tail  = state_s3_fwd.tail;
        default: state_s4_next.tail  = state_s4_next.tail;
      endcase // case (ucode_s3_r.push)

    end // block: exe_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : pipe_PROC

      // A one-cycle stall is incurred on back-to-back pops to the same queue
      // context.
      //
      s0_hazard               =   valid_s1_r
                                & (~ucode_s0_r.push)
                                & (~ucode_s1_r.push)
                                & (ucode_s0_r.ctxt == ucode_s1_r.ctxt)
                              ;
      stall_s0          = valid_s0_r & (s0_hazard);
      adv_s0            = valid_s0_r & (~stall_s0);

      cmd_accept        = (~stall_s0);
      cmd_adv           = (cmd_pass & cmd_accept);

      // Pre
      //
      ucode_s0_w        = '0;
      ucode_s0_w.push   = cmd_push;
      ucode_s0_w.data   = cmd_data;
      ucode_s0_w.ctxt   = cmd_ctxt;
      ucode_s0_w.link   = fp_alloc_id;

      // S0
      //
      ucode_s1_w        = ucode_s0_r;

      // S1
      //
      ucode_s2_w        = ucode_s1_r;
      ucode_s2_w.state  = state_s1_fwd;

      // S2
      //
      ucode_s3_w        = ucode_s2_r;
      ucode_s3_w.state  = state_s2_fwd;

      // S3
      //
      ucode_s4_w        = ucode_s3_r;
      ucode_s4_w.state  = state_s3_fwd;
      case (ucode_s3_r.push)
        1'b1: begin
          ucode_s4_w.state.empty  = 'b0;

          case (state_s3_fwd.empty)
            1'b1: begin
              ucode_s4_w.state.head  = ucode_s3_r.link;
              ucode_s4_w.state.tail  = ucode_s3_r.link;
              ucode_s4_w.link        = ucode_s3_r.link;
            end
            default: begin
              ucode_s4_w.state.head  = ucode_s3_r.link;
              ucode_s4_w.link        = ucode_s3_r.link;
            end
          endcase // case (ucode_s3_r.state.empty)
        end

        default: begin
          ucode_s4_w.link  = ucode_s3_r.state.tail;

          case (state_s3_fwd.empty)
            1'b1:    ucode_s4_w.empty_fault  = 'b1;
            default: begin
              ucode_s4_w.state.empty  = (state_s3_fwd.head == state_s3_fwd.tail);
              if (~ucode_s4_w.state.empty)
                ucode_s4_w.state.tail   = queue_table_dout;
            end
          endcase // case (ucode_s3_r.empty)
        end
      endcase // case (ucode_s3_r.push)

      // S4
      //
      state_s5_w              = ucode_s4_r.state;
      ctxt_s5_w               = ucode_s4_r.ctxt;


      //
      valid_s0_w              = (cmd_adv | stall_s0);
      valid_s1_w              = valid_s0_r & (~stall_s0);
      valid_s2_w              = valid_s1_r;
      valid_s3_w              = valid_s2_r;
      valid_s4_w              = valid_s3_r;
      valid_s5_w              = valid_s4_r;

      //
      ucode_s0_en             = cmd_adv;
      ucode_s1_en             = valid_s0_r & (~stall_s0);
      ucode_s2_en             = valid_s1_r;
      ucode_s3_en             = valid_s2_r;
      ucode_s4_en             = valid_s3_r;
      state_s5_en             = valid_s4_r;

    end // block: pipe_PROC


  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : state_table_PROC

      //
      state_table_en1    = adv_s0 & (~state_table_collision);
      state_table_wen1   = '0;
      state_table_din1   = '0;
      state_table_addr1  = ucode_s0_r.ctxt;

      //
      case (fsm_init_r [INIT_WRITE_B])
        1'b1: begin
          state_t s          = '0;
          s.empty            = 'b1;

          state_table_en2    = '1;
          state_table_wen2   = '1;
          state_table_din2   = s;
          state_table_addr2  = fsm_init_state_r.ctxt;
        end
        default: begin
          state_table_en2    = valid_s4_r;
          state_table_wen2   = '1;
          state_table_din2   = ucode_s4_r.state;
          state_table_addr2  = ucode_s4_r.ctxt;
        end
      endcase // case (fsm_init_r [INIT_BUSY_B])

    end // block: state_table_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : queue_table_PROC

      queue_table_en   = valid_s2_r & (~state_s2_fwd.empty);
      queue_table_wen  = ucode_s2_r.push;
      queue_table_din  = ucode_s2_r.link;
      case (ucode_s2_r.push)
        1'b1:    queue_table_addr  = state_s2_fwd.head;
        default: queue_table_addr  = state_s2_fwd_no_qt.tail;
      endcase // case (ucode_s2_r.push)

    end // block: queue_table_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    state_table_collision = valid_s4_r & (ucode_s4_r.ctxt == ucode_s0_r.ctxt);

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : s1_PROC

      //
      logic fwd__state_s5_to_s1;
      logic fwd__state_s4_to_s1;
      logic fwd__state_s3_to_s1;
      logic fwd__state_s2_to_s1;

      //
      fwd__state_s2_to_s1  = valid_s2_r & (ucode_s2_r.ctxt == ucode_s1_r.ctxt);
      fwd__state_s3_to_s1  = valid_s3_r & (ucode_s3_r.ctxt == ucode_s1_r.ctxt);
      fwd__state_s4_to_s1  = valid_s4_r & (ucode_s4_r.ctxt == ucode_s1_r.ctxt);
      fwd__state_s5_to_s1  = valid_s5_r & (ctxt_s5_r == ucode_s1_r.ctxt);

      //
      case (1'b1)
        fwd__state_s2_to_s1: state_s1_fwd  = ucode_s3_r.state;
        fwd__state_s3_to_s1: state_s1_fwd  = ucode_s4_w.state;
        fwd__state_s4_to_s1: state_s1_fwd  = ucode_s4_r.state;
        fwd__state_s5_to_s1: state_s1_fwd  = state_s5_r;
        default:             state_s1_fwd  = state_table_dout1;
      endcase

    end // block: s1_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : s2_PROC

      //
      logic fwd__state_s4_to_s2;
      logic fwd__state_s3_to_s2;

      //
      state_t s2           = ucode_s2_r.state;
      state_t s3           = ucode_s3_r.state;
      state_t s4_w         = ucode_s4_w.state;
      state_t s4           = ucode_s4_r.state;

      //
      fwd__state_s3_to_s2  = valid_s3_r & (ucode_s3_r.ctxt == ucode_s2_r.ctxt);
      fwd__state_s4_to_s2  = valid_s4_r & (ucode_s4_r.ctxt == ucode_s2_r.ctxt);

      //
      state_s2_fwd         = '0;

      //
      case (1'b1)
        fwd__state_s3_to_s2:  state_s2_fwd.empty  = s4_w.empty;
        fwd__state_s4_to_s2:  state_s2_fwd.empty  = s4.empty;
        default:              state_s2_fwd.empty  = s2.empty;
      endcase // case (1'b1)

      //
      case (1'b1)
        fwd__state_s3_to_s2:  state_s2_fwd.head  = s4_w.head;
        fwd__state_s4_to_s2:  state_s2_fwd.head  = s4.head;
        default:              state_s2_fwd.head  = s2.head;
      endcase // case (1'b1)

      // Tail is not modifyed on PUSH
      //
      case (1'b1)
        fwd__state_s3_to_s2:  state_s2_fwd.tail  = s4_w.tail;
        fwd__state_s4_to_s2:  state_s2_fwd.tail  = s4.tail;
        default:              state_s2_fwd.tail  = s2.tail;
      endcase // case (1'b1)

      case (1'b1)
        fwd__state_s3_to_s2:  state_s2_fwd_no_qt.tail  = s3.tail;
        fwd__state_s4_to_s2:  state_s2_fwd_no_qt.tail  = s4.tail;
        default:              state_s2_fwd_no_qt.tail  = s2.tail;
      endcase // case (1'b1)

    end // block: s2_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : s3_PROC

      //
      logic fwd__state_s4_to_s3;

      //
      state_t s4  = ucode_s4_r.state;

      fwd__state_s4_to_s3 = valid_s4_r & (ucode_s4_r.ctxt == ucode_s3_r.ctxt);

      //
      case (1'b1)
        fwd__state_s4_to_s3: state_s3_fwd  = s4;
        default:             state_s3_fwd  = ucode_s3_r.state;
      endcase // case (1'b1)

    end

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : status_PROC

      //
      full_w   = (~rst) & fp_all_alloc_w;

      //
      empty_w  = empty_r;

      //
      casez ({rst, valid_s4_r})
        2'b1_?:   empty_w                    = '1;
        2'b0_1:   empty_w [ucode_s4_r.ctxt]  = ucode_s4_r.state.empty;
        default:  empty_w                    = empty_r;
      endcase

    end // block: status_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : lkup_PROC

      //
      lkup_pass_w         = (~rst) & valid_s4_r;
      lkup_rnw_w          = (~ucode_s4_r.push);
      lkup_data_w         = ucode_s4_r.data;
      lkup_addr_w         = ucode_s4_r.link;
      lkup_empty_fault_w  = '0;

      //
      lkup_en             = lkup_pass_w;

    end // block: lkup_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb
    begin : fsm_init_PROC

      //
      fsm_init_w         = fsm_init_r;
      fsm_init_state_w   = fsm_init_state_r;
      fsm_init_state_en  = 'b0;

      case (fsm_init_r)

        INIT_RESET: begin
          fsm_init_state_w       = '0;
          fsm_init_state_w.ctxt  = '0;
          fsm_init_state_en      = 'b1;

          fsm_init_w             = INIT_EXE;
        end

        INIT_EXE: begin
          //
          fsm_init_state_en      = 'b1;
          fsm_init_state_w.ctxt  = fsm_init_state_r.ctxt + 'b1;
          //
          if (fsm_init_state_r.ctxt == ctxt_t'(CTXT - 1))
            fsm_init_w = INIT_DONE;
        end

        INIT_DONE:
          fsm_init_w = fsm_init_r;

        default:
          fsm_init_w = fsm_init_r;

      endcase // case (fsm_init_r)

      //
      fsm_init_en = (rst | fsm_init_r [INIT_BUSY_B]);

    end // block: fsm_init_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb busy_r = fsm_init_r [INIT_BUSY_B];

  // ======================================================================== //
  //                                                                          //
  // Sequential Logic                                                         //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    begin
      valid_s0_r <= valid_s0_w;
      valid_s1_r <= valid_s1_w;
      valid_s2_r <= valid_s2_w;
      valid_s3_r <= valid_s3_w;
      valid_s4_r <= valid_s4_w;
      valid_s5_r <= valid_s5_w;
    end

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (ucode_s0_en)
      ucode_s0_r <= ucode_s0_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (ucode_s1_en)
      ucode_s1_r <= ucode_s1_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (ucode_s2_en)
      ucode_s2_r <= ucode_s2_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (ucode_s3_en)
      ucode_s3_r <= ucode_s3_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (ucode_s4_en)
      ucode_s4_r <= ucode_s4_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (state_s5_en) begin
      state_s5_r <= state_s5_w;
      ctxt_s5_r  <= ctxt_s5_w;
    end

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    full_r <= full_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    empty_r <= empty_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (rst)
      fsm_init_r <= INIT_RESET;
    else if (fsm_init_en)
      fsm_init_r <= fsm_init_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (fsm_init_state_en)
      fsm_init_state_r <= fsm_init_state_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    lkup_pass_r  <= lkup_pass_w;

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    begin : lkup_oprands_REG
      if (lkup_en) begin
        lkup_rnw_r         <= lkup_rnw_w;
        lkup_data_r        <= lkup_data_w;
        lkup_addr_r        <= lkup_addr_w;
        lkup_empty_fault_r <= lkup_empty_fault_w;
      end
    end // block: lkup_oprands_REG

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  bitset #(.N(M)) u_fp (
      .clk                    (clk                )
    , .rst                    (rst                )
    , .alloc                  (fp_alloc           )
    , .alloc_id               (fp_alloc_id        )
    , .clear                  (fp_clear           )
    , .clear_id               (fp_clear_id        )
    , .state_r                (fp_state_r         )
    , .all_alloc_w            (fp_all_alloc_w     )
    , .all_clear_w            ()
  );

  // ------------------------------------------------------------------------ //
  //
  dpsram #(.W(STATE_W), .N(CTXT))u_state_table (
    // Port 1
      .clk1                   (clk                )
    , .en1                    (state_table_en1    )
    , .wen1                   (state_table_wen1   )
    , .addr1                  (state_table_addr1  )
    , .din1                   (state_table_din1   )
    , .dout1                  (state_table_dout1  )

    // Port 2
    , .clk2                   (clk                )
    , .en2                    (state_table_en2    )
    , .wen2                   (state_table_wen2   )
    , .addr2                  (state_table_addr2  )
    , .din2                   (state_table_din2   )
    , .dout2                  (state_table_dout2  )
  );

  // ------------------------------------------------------------------------ //
  //
  spsram #(.W(ADDR_W), .N(M)) u_queue_table (
      .clk                    (clk                )
    , .en                     (queue_table_en     )
    , .wen                    (queue_table_wen    )
    , .addr                   (queue_table_addr   )
    , .din                    (queue_table_din    )
    , .dout                   (queue_table_dout   )
  );

endmodule // linked_list_fifo
