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

#include <libtb.h>
#include <deque>
#include <sstream>
#include <array>
#include "Vlinked_list_queue.h"

#define PORTS(__func)                           \
    __func(cmd_pass, bool)                      \
    __func(cmd_push, bool)                      \
    __func(cmd_data, WordT)                     \
    __func(cmd_ctxt, CtxtT)                     \
    __func(cmd_accept, bool)                    \
    __func(resp_pass_r, bool)                   \
    __func(resp_data_w, WordT)                  \
    __func(resp_empty_fault_r, bool)            \
    __func(full_r, bool)                        \
    __func(empty_r, QueueT)                 \
    __func(busy_r, bool)

constexpr int OPT_N = 16;
constexpr int OPT_M = 128;

struct linked_list_queue_tb : libtb::TopLevel {
    using UUT = Vlinked_list_queue;
    //
    using WordT = uint32_t;
    using CtxtT = uint32_t;
    using QueueT = uint32_t;
    //
    struct Expectation {
        bool was_push;
        CtxtT c;
        WordT w;
    };

    SC_HAS_PROCESS(linked_list_queue_tb);
    linked_list_queue_tb (sc_core::sc_module_name mn = "t");
    void bind_rtl();

    void empty_fifo_sequence();
    void m_checker();
    void wait_not_busy();
    void b_issue_idle();
    void b_issue_command(const CtxtT & ctxt, bool is_push = true, WordT w = 0);

    const int N{10000};
    std::deque<Expectation> expectation_;
    std::array<std::deque<WordT>, OPT_N> fifo_;
#define __declare_signals(__name, __type)       \
    sc_core::sc_signal<__type> __name##_;
    PORTS(__declare_signals)
#undef __declare_signals
    UUT uut_;
};
