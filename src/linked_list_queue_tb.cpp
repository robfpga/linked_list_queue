//========================================================================== //
// Copyright (c) 2017, Stephen Henry
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

#include "linked_list_queue_tb.h"

linked_list_queue_tb::linked_list_queue_tb (sc_core::sc_module_name mn)
    : uut_("uut")
    , libtb::TopLevel(mn)
#define __declare_signals(__name, __type)       \
    , __name##_(#__name)
    PORTS(__declare_signals)
#undef __declare_signals
{
    bind_rtl();

    dont_initialize();
    SC_METHOD(m_checker);
    sensitive << e_tb_sample();
}

void linked_list_queue_tb::bind_rtl()
{
    uut_.clk(clk());
    uut_.rst(rst());
#define __bind_signals(__name, __type)          \
    uut_.__name(__name##_);
    PORTS(__bind_signals)
#undef __bind_signals
}

void linked_list_queue_tb::m_checker() {

    if (resp_pass_r_) {

        if (expectation_.size() == 0) {
            LIBTB_REPORT_INFO("Unexpected response");
            return;
        }

        const Expectation expected = expectation_.front();
        expectation_.pop_front();

        if (expected.was_push)
            return;

        const WordT actual = resp_data_w_;
        if (actual != expected.w) {
            std::stringstream ss;

            ss << "Mismatch on CTXT=" << expected.c
               << " Expected: " << std::hex << expected.w
               << " Actual: " << std::hex << actual;
            LIBTB_REPORT_ERROR(ss.str());
        } else {
            std::stringstream ss;

            ss << "Match on CTXT=" << expected.c
               << " Expected: " << std::hex << expected.w;
//                LIBTB_REPORT_DEBUG(ss.str());
        }
    }
}

void linked_list_queue_tb::wait_not_busy() {
    do { t_wait_sync(); } while (busy_r_);
    t_wait_posedge_clk();
}

void linked_list_queue_tb::empty_fifo_sequence() {
    for (int ctxt = 0; ctxt < OPT_N; ctxt++) {

        std::size_t s = fifo_[ctxt].size();

        while (s--)
            b_issue_command(ctxt, false);
    }
}

void linked_list_queue_tb::b_issue_idle() {
    cmd_pass_ = false;
    cmd_push_ = false;
    cmd_data_ = WordT();
    cmd_ctxt_ = CtxtT();
}

void linked_list_queue_tb::b_issue_command (
    const CtxtT & ctxt, bool is_push, WordT w) {
    cmd_pass_ = true;
    cmd_push_ = is_push;
    cmd_ctxt_ = ctxt;
    cmd_data_ = w;
    do { t_wait_sync(); } while (!cmd_accept_);

    if (is_push) {
        std::stringstream ss;
        ss << "Pushing CTXT=: " << ctxt << " " << std::hex << w;
//                LIBTB_REPORT_DEBUG(ss.str());

        fifo_[ctxt].push_back(w);
        Expectation e;
        e.was_push = true;
        expectation_.push_back(e);
    }
    else {
        std::stringstream ss;
        ss << "Popping CTXT=: " << ctxt;
//                LIBTB_REPORT_DEBUG(ss.str());

        Expectation e;
        e.c = ctxt;
        e.w = fifo_[ctxt].front();
        e.was_push = false;
        fifo_[ctxt].pop_front();
        expectation_.push_back(e);
    }
    t_wait_posedge_clk();
    b_issue_idle();
}
