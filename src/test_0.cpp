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

struct test_0 : public linked_list_queue_tb
{
    SC_HAS_PROCESS(test_0);
    test_0() {}
    bool run_test () {
        wait_not_busy();
        LIBTB_REPORT_INFO("Stimulus starts...");

        wait_not_busy();

        int occupancy = 0;
        for (int i = 0; i < N; i++) {
            const CtxtT c = libtb::random_integer_in_range(OPT_N - 1);
            const WordT w = libtb::random<WordT>();

            if (occupancy > 100) {
                // Flush all contexts when overall occupancy reaches a certain
                // limit. Queue behavior is undefined on any attempt to push
                // during on a FULL state.
                //
                empty_fifo_sequence();
                occupancy = 0;
            }

            bool is_push = true;
            if (fifo_[c].size() != 0)
                is_push = (libtb::random_integer_in_range(100) < 50);

            if (is_push)
                occupancy++;
            else
                occupancy--;

            b_issue_command (c, is_push, w);
        }
        empty_fifo_sequence();
        t_wait_posedge_clk(20);

        t_wait_sync();
        if (!empty_r_)
            LIBTB_REPORT_ERROR("Fifo does not report empty on EOS");

        LIBTB_REPORT_INFO("Stimulus ends.");
        return false;
    }
};

int sc_main (int argc, char **argv)
{
    using namespace libtb;
    return LibTbSim<test_0>(argc, argv).start();
}
