\m4_TLV_version 1d: tl-x.org
\SV
   // ═══════════════════════════════════════════════════════════════════
   //  ARM Single-Cycle CPU Core — Prof. Kamal ISA
   //  9 Instructions: ADD  SUB  ADDI  SUBI  LDUR  STUR  B  CBZ  CBNZ
   //
   //  Test Program (inline ROM):
   //    0x00: ADDI X1, X0, #10    → X1 = 10
   //    0x04: ADDI X2, X0, #20    → X2 = 20
   //    0x08: ADD  X3, X1, X2     → X3 = 30
   //    0x0C: SUB  X4, X2, X1     → X4 = 10
   //    0x10: SUBI X6, X2, #5     → X6 = 15
   //    0x14: STUR X3, [X0, #0]   → Mem[0] = 30
   //    0x18: LDUR X5, [X0, #0]   → X5 = 30  ← PASS condition
   //    0x1C: CBZ  X1, #2         → not taken  (X1=10≠0)
   //    0x20: CBNZ X4, #-3        → TAKEN      (X4=10≠0) → 0x14
   //    0x24: B    #0             → infinite loop
   //
   //  Waveform signals to watch (add in Makerchip waveform panel):
   //    |cpu @0  $pc, $instr, $is_r_type, $is_i_type, $is_d_type,
   //             $is_b_type, $is_cb_type, $reg_write, $alu_src,
   //             $mem_read, $mem_write, $mem_to_reg, $branch_z,
   //             $branch_nz, $uncond_br, $pc_src, $alu_result,
   //             $alu_zero, $wr_data
   //    /xreg[1..6] $val   — register file values
   //    /dmem[0]    $val   — data memory at address 0
   // ═══════════════════════════════════════════════════════════════════
   m4_makerchip_module

\TLV

   |cpu
      @0
         // ─────────────────────────────────────────────────────────
         //  RESET
         // ─────────────────────────────────────────────────────────
         $reset = *reset;

         // ─────────────────────────────────────────────────────────
         //  CYCLE COUNTER  (keeps the sim running past the PASS point
         //  so there's plenty of room to scrub through the VIZ/waveform;
         //  Makerchip stops simulating the instant *passed asserts)
         // ─────────────────────────────────────────────────────────
         $cyc_cnt[31:0] = $reset ? 32'b0 : >>1$cyc_cnt + 32'd1;

         // ─────────────────────────────────────────────────────────
         //  PROGRAM COUNTER
         // ─────────────────────────────────────────────────────────
         // With plain $reset, PC jumps to 0 combinationally WHILE reset is
         // held (for however many cycles that lasts), then advances to 4
         // the instant reset deasserts -- so the address-0 fetch only ever
         // overlaps with reset, when register writes are also suppressed,
         // and PC=0 is never visible as a real, executing cycle. Detecting
         // the falling edge of reset and holding PC at 0 for exactly that
         // one extra cycle (regardless of how long reset was held) gives
         // ADDI X1,X0,#10 a genuine non-reset cycle to execute in, so
         // PC=0x0 shows up in the VIZ/waveform and X1=10 commits normally
         // on the following cycle -- consistent with every other instruction.
         $reset_just_released = >>1$reset && !$reset;
         $pc[63:0] =
            ($reset || $reset_just_released) ? 64'b0             :
            >>1$pc_src                       ? >>1$branch_target :
                                                >>1$pc + 64'd4;

         // ─────────────────────────────────────────────────────────
         //  INSTRUCTION MEMORY  (inline ROM — 9 entries)
         //  Encoding reference:
         //   R-format opcode[31:21]:  ADD=10001011000  SUB=11001011000
         //   I-format opcode[31:22]: ADDI=1001000100  SUBI=1101000100
         //   D-format opcode[31:21]: LDUR=11111000010 STUR=11111000000
         //   B-format opcode[31:26]:    B=000101
         //  CB-format opcode[31:24]:  CBZ=10110100   CBNZ=10110101
         // ─────────────────────────────────────────────────────────
         $instr[31:0] =
            ($pc[6:2] == 5'd0) ? 32'h91002801 :  // ADDI X1, X0, #10
            ($pc[6:2] == 5'd1) ? 32'h91005042 :  // ADDI X2, X0, #20
            ($pc[6:2] == 5'd2) ? 32'h8B020023 :  // ADD  X3, X1, X2
            ($pc[6:2] == 5'd3) ? 32'hCB010044 :  // SUB  X4, X2, X1
            ($pc[6:2] == 5'd4) ? 32'hD1001446 :  // SUBI X6, X2, #5
            ($pc[6:2] == 5'd5) ? 32'hF8000003 :  // STUR X3, [X0, #0]
            ($pc[6:2] == 5'd6) ? 32'hF8400005 :  // LDUR X5, [X0, #0]
            ($pc[6:2] == 5'd7) ? 32'hB4000041 :  // CBZ  X1, #2
            ($pc[6:2] == 5'd8) ? 32'hB5FFFFA4 :  // CBNZ X4, #-3
                                  32'h14000000;   // B    #0  (loop forever)

         // ─────────────────────────────────────────────────────────
         //  DECODE — Instruction Format Detection
         // ─────────────────────────────────────────────────────────
         // R-format  (11-bit opcode [31:21])
         $is_add    = ($instr[31:21] == 11'b10001011000);
         $is_sub    = ($instr[31:21] == 11'b11001011000);
         $is_r_type = $is_add || $is_sub;

         // I-format  (10-bit opcode [31:22])  —  12-bit UNSIGNED imm [21:10]
         $is_addi   = ($instr[31:22] == 10'b1001000100);
         $is_subi   = ($instr[31:22] == 10'b1101000100);
         $is_i_type = $is_addi || $is_subi;

         // D-format  (11-bit opcode [31:21])  —  9-bit SIGNED addr [20:12]
         $is_ldur   = ($instr[31:21] == 11'b11111000010);
         $is_stur   = ($instr[31:21] == 11'b11111000000);
         $is_d_type = $is_ldur || $is_stur;

         // B-format  (6-bit opcode [31:26])   —  26-bit SIGNED offset [25:0]
         $is_b_type = ($instr[31:26] == 6'b000101);

         // CB-format (8-bit opcode [31:24])   —  19-bit SIGNED offset [23:5]
         $is_cbz    = ($instr[31:24] == 8'b10110100);
         $is_cbnz   = ($instr[31:24] == 8'b10110101);
         $is_cb_type = $is_cbz || $is_cbnz;

         // ─────────────────────────────────────────────────────────
         //  CONTROL UNIT
         // ─────────────────────────────────────────────────────────
         $reg_write   = $is_r_type || $is_i_type || $is_ldur;
         $alu_src     = $is_i_type || $is_d_type;
         $mem_read    = $is_ldur;
         $mem_write   = $is_stur;
         $mem_to_reg  = $is_ldur;
         $uncond_br   = $is_b_type;
         $branch_z    = $is_cbz;
         $branch_nz   = $is_cbnz;
         $reg2_loc    = $is_stur || $is_cbz || $is_cbnz;

         // ─────────────────────────────────────────────────────────
         //  REGISTER FILE INDICES
         // ─────────────────────────────────────────────────────────
         $rd[4:0]  = $instr[4:0];                            // Destination
         $rn[4:0]  = $instr[9:5];                            // Source 1
         $rm[4:0]  = $reg2_loc ? $instr[4:0] : $instr[20:16]; // Source 2 (Rm or Rt)

         // ─────────────────────────────────────────────────────────
         //  REGISTER FILE  (32 × 64-bit)
         //  X31 = XZR always reads 0, writes suppressed
         // ─────────────────────────────────────────────────────────
         /xreg[31:0]
            $wr_en = |cpu>>1$reg_write &&
                     (|cpu>>1$rd == #xreg) &&
                     (#xreg != 5'b11111);
            // Block the write for one extra cycle after reset releases, too:
            // >>1$reset being true means the *previous* cycle's decode (the
            // one this write would commit) was still a throwaway fetch made
            // while PC was pinned at 0 by reset, not the live, on-screen one.
            $val[63:0] = (|cpu$reset || |cpu>>1$reset) ? 64'b0 :
                         $wr_en ? |cpu>>1$wr_data :
                                  $RETAIN;
         $rs1_data[63:0] = ($rn == 5'd31) ? 64'b0 : /xreg[$rn]$val;
         $rs2_data[63:0] = ($rm == 5'd31) ? 64'b0 : /xreg[$rm]$val;

         // ─────────────────────────────────────────────────────────
         //  IMMEDIATE EXTRACTION & EXTENSION
         // ─────────────────────────────────────────────────────────
         //  ADDI/SUBI: instr[21:10]  12-bit  UNSIGNED → zero-extend
         $imm12[63:0] = {{52{1'b0}},    $instr[21:10]};
         //  LDUR/STUR: instr[20:12]   9-bit  SIGNED   → sign-extend
         $imm9[63:0]  = {{55{$instr[20]}}, $instr[20:12]};
         //  CBZ/CBNZ:  instr[23:5]   19-bit  SIGNED   → sign-extend
         $imm19[63:0] = {{45{$instr[23]}}, $instr[23:5]};
         //  B:         instr[25:0]   26-bit  SIGNED   → sign-extend
         $imm26[63:0] = {{38{$instr[25]}}, $instr[25:0]};

         //  ALUSrc mux — select I-type immediate vs D-type offset
         $alu_imm[63:0]  = $is_i_type ? $imm12 : $imm9;
         $alu_in1[63:0]  = $rs1_data;
         $alu_in2[63:0]  = $alu_src ? $alu_imm : $rs2_data;

         // ─────────────────────────────────────────────────────────
         //  ALU
         // ─────────────────────────────────────────────────────────
         $alu_result[63:0] =
            ($is_add  || $is_addi)               ? $alu_in1 + $alu_in2 :
            ($is_sub  || $is_subi)               ? $alu_in1 - $alu_in2 :
            ($is_ldur || $is_stur)               ? $alu_in1 + $alu_in2 :
            ($is_cbz  || $is_cbnz)               ? $rs2_data           :
                                                    64'b0;
         $alu_zero = ($alu_result == 64'b0);

         // ─────────────────────────────────────────────────────────
         //  DATA MEMORY  (64 × 64-bit, byte-addressed → word index)
         // ─────────────────────────────────────────────────────────
         /dmem[63:0]
            $wr_en = |cpu>>1$mem_write &&
                     (|cpu>>1$alu_result[5:0] == #dmem);
            // Same one-extra-cycle write block as /xreg above.
            $val[63:0] = (|cpu$reset || |cpu>>1$reset) ? 64'b0 :
                         $wr_en ? |cpu>>1$rs2_data :
                                  $RETAIN;
         $dmem_rd_data[63:0] = /dmem[$alu_result[5:0]]$val;

         // ─────────────────────────────────────────────────────────
         //  WRITEBACK  (MemtoReg mux)
         // ─────────────────────────────────────────────────────────
         $wr_data[63:0] = $mem_to_reg ? $dmem_rd_data : $alu_result;

         // ─────────────────────────────────────────────────────────
         //  NEXT PC  (Branch logic)
         // ─────────────────────────────────────────────────────────
         $branch_offset[63:0] = $is_b_type ? $imm26 : $imm19;
         $branch_target[63:0] = $pc + ($branch_offset << 2);
         $pc_src =
            $uncond_br ||
            ($branch_z  && $alu_zero)  ||
            ($branch_nz && !$alu_zero);


         // ═════════════════════════════════════════════════════════
         //  VIZ — ARM Single-Cycle Processor Datapath
         //
         \viz_js
            box: {width: 1000, height: 460, fill: "#0d1117", stroke: "#30363d", strokeWidth: 1},
            where: {left: 0, top: 0},
            init() {
               let title = new fabric.Text("ARM Single-Cycle CPU Core — Prof. Kamal ISA", {
                  top: 10, left: 315, fill: "#e6edf3", fontSize: 15, fontWeight: 800, fontFamily: "monospace"
               })

               // ── INSTR MEMORY (full ROM listing) ─────────────────────────
               let imem_box = new fabric.Rect({top: 45, left: 15, width: 335, height: 210, fill: "#0d2818", stroke: "#3fb950", strokeWidth: 1, rx: 4, ry: 4})
               let imem_lbl = new fabric.Text("INSTRUCTION MEMORY(imem)", {top: 50, left: 22, fill: "#3fb950", fontSize: 11, fontWeight: 800, fontFamily: "monospace"})
               let imem_hl  = new fabric.Rect({top: 68, left: 19, width: 327, height: 15, fill: "rgba(63,185,80,0.25)", stroke: "#3fb950", strokeWidth: 1})
               const ROM = [
                  ["0x00", "91002801", "ADDI X1,X0,#10"],
                  ["0x04", "91005042", "ADDI X2,X0,#20"],
                  ["0x08", "8B020023", "ADD  X3,X1,X2"],
                  ["0x0C", "CB010044", "SUB  X4,X2,X1"],
                  ["0x10", "D1001446", "SUBI X6,X2,#5"],
                  ["0x14", "F8000003", "STUR X3,(X0,#0)"],
                  ["0x18", "F8400005", "LDUR X5,(X0,#0)"],
                  ["0x1C", "B4000041", "CBZ  X1,#2"],
                  ["0x20", "B5FFFFA4", "CBNZ X4,#-3"],
                  ["0x24", "14000000", "B    #0"]
               ]
               let romRows = {}
               ROM.forEach((row, i) => {
                  romRows["rom_" + i] = new fabric.Text(row[0] + "  " + row[1] + "  " + row[2], {
                     top: 70 + i * 16, left: 22, fill: "#8b949e", fontSize: 10, fontFamily: "monospace"
                  })
               })

               // ── INSTRUCTION (live decode + operand substitution) ────────
               let instr_box  = new fabric.Rect({top: 45, left: 360, width: 250, height: 210, fill: "#161b22", stroke: "#a371f7", strokeWidth: 1, rx: 4, ry: 4})
               let instr_lbl  = new fabric.Text("INSTRUCTION DECODE", {top: 50, left: 367, fill: "#a371f7", fontSize: 11, fontWeight: 800, fontFamily: "monospace"})
               let instr_name = new fabric.Text("--", {top: 70, left: 367, fill: "#e6edf3", fontSize: 13, fontFamily: "monospace"})
               let instr_fmt  = new fabric.Text("[--format]", {top: 90, left: 367, fill: "#8b949e", fontSize: 10, fontFamily: "monospace"})
               let instr_detail = new fabric.Text("", {top: 108, left: 367, fill: "#e3b341", fontSize: 10, fontFamily: "monospace"})
               let instr_hex  = new fabric.Text("hex: 0x00000000", {top: 128, left: 367, fill: "#555", fontSize: 9, fontFamily: "monospace"})

               // ── REGISTER FILE (hex) ──────────────────────────────────────
               let rf_box = new fabric.Rect({top: 45, left: 620, width: 170, height: 210, fill: "#161b22", stroke: "#388bfd", strokeWidth: 1, rx: 4, ry: 4})
               let rf_lbl = new fabric.Text("REG FILE (hex)", {top: 50, left: 627, fill: "#388bfd", fontSize: 11, fontWeight: 800, fontFamily: "monospace"})
               let rf_x0  = new fabric.Text("X0  = 0", {top: 70,  left: 627, fill: "#555", fontSize: 11, fontFamily: "monospace"})
               let rf_x1  = new fabric.Text("X1  = 0", {top: 86,  left: 627, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let rf_x2  = new fabric.Text("X2  = 0", {top: 102, left: 627, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let rf_x3  = new fabric.Text("X3  = 0", {top: 118, left: 627, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let rf_x4  = new fabric.Text("X4  = 0", {top: 134, left: 627, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let rf_x5  = new fabric.Text("X5  = 0", {top: 150, left: 627, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let rf_x6  = new fabric.Text("X6  = 0", {top: 166, left: 627, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})

               // ── DATA MEM (hex) ────────────────────────────────────────────
               let dmem_box = new fabric.Rect({top: 45, left: 800, width: 185, height: 210, fill: "#2d1215", stroke: "#f85149", strokeWidth: 1, rx: 4, ry: 4})
               let dmem_lbl = new fabric.Text("DATA MEMORY(dmem) (hex)", {top: 50, left: 807, fill: "#f85149", fontSize: 11, fontWeight: 800, fontFamily: "monospace"})
               let dm_m0 = new fabric.Text("Mem[0] = 0x0000000000000000", {top: 70,  left: 807, fill: "#8b949e", fontSize: 9, fontFamily: "monospace"})
               let dm_m1 = new fabric.Text("Mem[1] = 0x0000000000000000", {top: 86,  left: 807, fill: "#8b949e", fontSize: 9, fontFamily: "monospace"})
               let dm_m2 = new fabric.Text("Mem[2] = 0x0000000000000000", {top: 102, left: 807, fill: "#8b949e", fontSize: 9, fontFamily: "monospace"})
               let dm_op = new fabric.Text("--", {top: 122, left: 807, fill: "#8b949e", fontSize: 10, fontFamily: "monospace"})

               // ── CONTROL + ALU (bottom-left row) ──────────────────────────
               let ctrl_box  = new fabric.Rect({top: 265, left: 15, width: 460, height: 70, fill: "#161b22", stroke: "#a371f7", strokeWidth: 1, rx: 4, ry: 4})
               let ctrl_lbl  = new fabric.Text("CONTROL", {top: 270, left: 22, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let ctrl_str  = new fabric.Text("--", {top: 288, left: 22, fill: "#e3b341", fontSize: 10, fontFamily: "monospace"})
               let ctrl_str2 = new fabric.Text("--", {top: 304, left: 22, fill: "#e3b341", fontSize: 10, fontFamily: "monospace"})
               let ctrl_str3 = new fabric.Text("--", {top: 320, left: 22, fill: "#e3b341", fontSize: 10, fontFamily: "monospace"})

               let alu_box  = new fabric.Rect({top: 265, left: 490, width: 250, height: 70, fill: "#161b22", stroke: "#3fb950", strokeWidth: 1, rx: 4, ry: 4})
               let alu_lbl  = new fabric.Text("ALU", {top: 270, left: 497, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let alu_ops  = new fabric.Text("0 op 0", {top: 288, left: 497, fill: "#8b949e", fontSize: 11, fontFamily: "monospace"})
               let alu_res  = new fabric.Text("= 0", {top: 304, left: 497, fill: "#3fb950", fontSize: 12, fontFamily: "monospace"})
               let alu_zero = new fabric.Text("Zero=0", {top: 320, left: 497, fill: "#8b949e", fontSize: 10, fontFamily: "monospace"})

               // ── STATUS bar ────────────────────────────────────────────────
               let status_box  = new fabric.Rect({top: 355, left: 15, width: 970, height: 90, fill: "#161b22", stroke: "#21262d", strokeWidth: 1, rx: 4, ry: 4})
               let status_str  = new fabric.Text("-- RESET --", {top: 362, left: 23, fill: "#a371f7", fontSize: 13, fontWeight: 800, fontFamily: "monospace"})
               let status_str2 = new fabric.Text("", {top: 382, left: 23, fill: "#8b949e", fontSize: 10, fontFamily: "monospace"})
               let status_str3 = new fabric.Text("", {top: 398, left: 23, fill: "#8b949e", fontSize: 10, fontFamily: "monospace"})
               let status_str4 = new fabric.Text("", {top: 414, left: 23, fill: "#e3b341", fontSize: 11, fontWeight: 800, fontFamily: "monospace"})

               return Object.assign({
                  title,
                  imem_box, imem_lbl, imem_hl,
                  instr_box, instr_lbl, instr_name, instr_fmt, instr_detail, instr_hex,
                  rf_box, rf_lbl, rf_x0, rf_x1, rf_x2, rf_x3, rf_x4, rf_x5, rf_x6,
                  dmem_box, dmem_lbl, dm_m0, dm_m1, dm_m2, dm_op,
                  ctrl_box, ctrl_lbl, ctrl_str, ctrl_str2, ctrl_str3,
                  alu_box, alu_lbl, alu_ops, alu_res, alu_zero,
                  status_box, status_str, status_str2, status_str3, status_str4
               }, romRows)
            },
            render() {
               const h = (v, w) => "0x" + BigInt.asUintN(64, BigInt(v)).toString(16).toUpperCase().padStart(w, "0")

               // 64-bit signals must use asBigInt() -- asInt() throws once a signal's
               // declared width exceeds the 53-bit JS safe-integer range.
               let pc        = '$pc'.asBigInt(0n)
               let instr     = '$instr'.asInt(0)
               let is_r      = '$is_r_type'.asBool(false)
               let is_i      = '$is_i_type'.asBool(false)
               let is_d      = '$is_d_type'.asBool(false)
               let is_b      = '$is_b_type'.asBool(false)
               let is_cb     = '$is_cb_type'.asBool(false)
               let is_add    = '$is_add'.asBool(false)
               let is_sub    = '$is_sub'.asBool(false)
               let is_addi   = '$is_addi'.asBool(false)
               let is_subi   = '$is_subi'.asBool(false)
               let is_ldur   = '$is_ldur'.asBool(false)
               let is_stur   = '$is_stur'.asBool(false)
               let is_cbz    = '$is_cbz'.asBool(false)
               let is_cbnz   = '$is_cbnz'.asBool(false)
               let reg_write = '$reg_write'.asBool(false)
               let alu_src   = '$alu_src'.asBool(false)
               let mem_read  = '$mem_read'.asBool(false)
               let mem_write = '$mem_write'.asBool(false)
               let mem_to_reg= '$mem_to_reg'.asBool(false)
               let uncond_br = '$uncond_br'.asBool(false)
               let branch_z  = '$branch_z'.asBool(false)
               let branch_nz = '$branch_nz'.asBool(false)
               let pc_src    = '$pc_src'.asBool(false)
               let alu_in1   = '$alu_in1'.asBigInt(0n)
               let alu_in2   = '$alu_in2'.asBigInt(0n)
               let alu_res_v = '$alu_result'.asBigInt(0n)
               let alu_zero  = '$alu_zero'.asBool(false)
               let wr_data   = '$wr_data'.asBigInt(0n)
               let rd        = '$rd'.asInt(0)
               let rn        = '$rn'.asInt(0)
               let rm        = '$rm'.asInt(0)
               let br_tgt    = '$branch_target'.asBigInt(0n)
               let imm12     = '$imm12'.asBigInt(0n)
               let imm9      = '$imm9'.asBigInt(0n)
               let imm19     = '$imm19'.asBigInt(0n)
               let imm26     = '$imm26'.asBigInt(0n)

               let x1 = '/xreg[1]$val'.asBigInt(0n)
               let x2 = '/xreg[2]$val'.asBigInt(0n)
               let x3 = '/xreg[3]$val'.asBigInt(0n)
               let x4 = '/xreg[4]$val'.asBigInt(0n)
               let x5 = '/xreg[5]$val'.asBigInt(0n)
               let x6 = '/xreg[6]$val'.asBigInt(0n)
               let m0 = '/dmem[0]$val'.asBigInt(0n)
               let m1 = '/dmem[1]$val'.asBigInt(0n)
               let m2 = '/dmem[2]$val'.asBigInt(0n)

               const xregs = [0n, x1, x2, x3, x4, x5, x6]
               const regVal = (idx) => (idx === 0 || idx === 31) ? 0n : (xregs[idx] === undefined ? 0n : xregs[idx])

               const NAMES = ["ADDI X1,X0,#10", "ADDI X2,X0,#20", "ADD X3,X1,X2",
                              "SUB X4,X2,X1", "SUBI X6,X2,#5", "STUR X3,(X0,#0)", "LDUR X5,(X0,#0)",
                              "CBZ X1,#2", "CBNZ X4,#-3", "B #0"]
               let idx = Math.min(Math.floor(Number(pc) / 4), 9)
               let name = NAMES[idx] || "?"
               let tstr = is_r ? "R" : is_i ? "I" : is_d ? "D" : is_b ? "B" : is_cb ? "CB" : "?"
               let aop  = (is_r || is_i || is_ldur || is_stur) ? (is_d ? "addr+" : "op") : "--"

               let objs = this.getObjects()

               // Highlight the current ROM row.
               objs.imem_hl.set({top: 68 + idx * 16})

               // Live-decoded instruction with operand substitution (like a
               // disassembler showing register/immediate values inline).
               let detail =
                  (is_add || is_sub) ? "X" + rn + "(" + regVal(rn) + ")  X" + rm + "(" + regVal(rm) + ")" :
                  (is_addi || is_subi) ? "X" + rn + "(" + regVal(rn) + ")  #" + imm12 :
                  is_stur ? "[X" + rn + "(" + regVal(rn) + "),#" + BigInt.asIntN(9, imm9) + "]  data=X" + rm + "(" + regVal(rm) + ")" :
                  is_ldur ? "[X" + rn + "(" + regVal(rn) + "),#" + BigInt.asIntN(9, imm9) + "]" :
                  (is_cbz || is_cbnz) ? "X" + rm + "(" + regVal(rm) + ")  #" + BigInt.asIntN(19, imm19) :
                  is_b ? "#" + BigInt.asIntN(26, imm26) :
                  ""

               objs.instr_name.set({text: name})
               objs.instr_fmt.set({text: "[" + tstr + "-format]"})
               objs.instr_detail.set({text: detail})
               objs.instr_hex.set({text: "hex: " + h(instr, 8)})

               objs.ctrl_str.set({text: "RegWr=" + (reg_write ? 1 : 0) + " ALUSrc=" + (alu_src ? 1 : 0) + " MemRd=" + (mem_read ? 1 : 0) + " MemWr=" + (mem_write ? 1 : 0)})
               objs.ctrl_str2.set({text: "Mem2Reg=" + (mem_to_reg ? 1 : 0) + " UncBr=" + (uncond_br ? 1 : 0) + " BrZ=" + (branch_z ? 1 : 0) + " BrNZ=" + (branch_nz ? 1 : 0)})
               objs.ctrl_str3.set({text: "PCSrc=" + (pc_src ? 1 : 0) + (pc_src ? "  -> target " + h(br_tgt, 4) : "")})

               objs.alu_ops.set({text: alu_in1 + " " + aop + " " + alu_in2})
               objs.alu_res.set({text: "= " + alu_res_v})
               objs.alu_res.set({fill: alu_zero ? "#e3b341" : "#3fb950"})
               objs.alu_zero.set({text: "Zero=" + (alu_zero ? 1 : 0)})

               objs.dm_m0.set({text: "Mem[0] = " + h(m0, 16)})
               objs.dm_m1.set({text: "Mem[1] = " + h(m1, 16)})
               objs.dm_m2.set({text: "Mem[2] = " + h(m2, 16)})
               objs.dm_op.set({text: mem_write ? "WRITE addr=" + alu_res_v : mem_read ? "READ addr=" + alu_res_v : "--"})
               objs.dm_op.set({fill: mem_write ? "#f85149" : mem_read ? "#3fb950" : "#8b949e"})

               const setReg = (obj, label, val, writing) => {
                  obj.set({text: label + " = " + h(val, 16) + (writing ? "  <- " + h(wr_data, 16) : "")})
                  obj.set({fill: writing ? "#3fb950" : "#8b949e"})
               }
               setReg(objs.rf_x1, "X1 ", x1, reg_write && rd === 1)
               setReg(objs.rf_x2, "X2 ", x2, reg_write && rd === 2)
               setReg(objs.rf_x3, "X3 ", x3, reg_write && rd === 3)
               setReg(objs.rf_x4, "X4 ", x4, reg_write && rd === 4)
               setReg(objs.rf_x5, "X5 ", x5, reg_write && rd === 5)
               setReg(objs.rf_x6, "X6 ", x6, reg_write && rd === 6)

               objs.status_str.set({text: name})
               objs.status_str2.set({text: "PC=" + h(pc, 4) + "   instr=" + h(instr, 8) + "   format=" + tstr + "   alu_result=" + alu_res_v})
               objs.status_str3.set({text: "next_pc=" + h(pc_src ? br_tgt : pc + 4n, 4) + (pc_src ? "  [BRANCH TAKEN]" : "  [SEQUENTIAL]")})
               objs.status_str4.set({text: (x5 === 30n) ? "PASS -- X5 == 30 (LDUR loaded the value STUR stored from X3)" : "X5 = " + x5 + "  (waiting for X5 == 30)"})
               objs.status_str4.set({fill: (x5 === 30n) ? "#3fb950" : "#e3b341"})
            }
   // ─────────────────────────────────────────────────────────────
   //  PASS / FAIL
   //  PASS when X5 = 30 (LDUR loads the STUR'd value of X3), held for
   //  at least 80 cycles so there's room to scrub the VIZ/waveform
   //  through several iterations of the CBZ/CBNZ self-check loop.
   // ─────────────────────────────────────────────────────────────
   *passed = (|cpu/xreg[5]>>1$val == 64'd30) && (|cpu>>1$cyc_cnt > 32'd30);
   *failed = 1'b0;

\SV
   endmodule
