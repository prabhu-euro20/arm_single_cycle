\m4_TLV_version 1d: tl-x.org
\SV
   // ═══════════════════════════════════════════════════════════════════
   //  ARM Single-Cycle CPU Core
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
         //  VIZ — LEGv8-style Single-Cycle Datapath
         //  teal header/toolbar, dark code editor with highlighted current
         //  line, CPU Log panel, register grid, and a schematic single-cycle
         //  datapath (PC, Instruction Memory, Registers, Sign-extend, ALU,
         //  Data Memory, muxes, branch adder) with the active signal path
         //  highlighted per instruction.
         //
         \viz_js
            box: {width: 1080, height: 830, fill: "#0d1117", stroke: "#30363d", strokeWidth: 1},
            where: {left: 0, top: 0},
            init() {
               const mkLine = (x1,y1,x2,y2) => new fabric.Line([x1,y1,x2,y2], {stroke: "#c9d2de", strokeWidth: 1.2, selectable: false, evented: false})
               const mkPoly = (pts) => new fabric.Polyline(pts, {fill: "", stroke: "#c9d2de", strokeWidth: 1.2, selectable: false, evented: false})
               const mkBox  = (x,y,w,h) => new fabric.Rect({left: x, top: y, width: w, height: h, fill: "#ffffff", stroke: "#555555", strokeWidth: 1, rx: 3, ry: 3, selectable: false, evented: false})
               const mkTxt  = (x,y,s,size,colorv,boldv) => new fabric.Text(s, {left: x, top: y, fontSize: size || 9, fill: colorv || "#222222", fontFamily: "monospace", fontWeight: boldv ? 700 : 400, selectable: false, evented: false})
               const mkTrap = (pts) => new fabric.Polygon(pts, {fill: "#ffffff", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})
               // Adder units are drawn as a house-shaped pentagon.
               const mkAdd  = (x,y,w,h) => new fabric.Polygon([{x:x,y:y},{x:x+w*0.65,y:y},{x:x+w,y:y+h/2},{x:x+w*0.65,y:y+h},{x:x,y:y+h}], {fill: "#ffffff", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})
               // The ALU gets the classic notched hexagon symbol (concave on
               // the left where the two operands enter, pointed on the right).
               const mkALU  = (x,y,w,h) => new fabric.Polygon([{x:x,y:y},{x:x+w*0.75,y:y},{x:x+w,y:y+h/2},{x:x+w*0.75,y:y+h},{x:x,y:y+h},{x:x+w*0.2,y:y+h/2}], {fill: "#ffffff", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})
               // AND gate: classic IEEE-shape not simple square shape
               const mkAndGate = (x,y,w,h) => new fabric.Path(
                  "M " + x + " " + y + " L " + (x+w*0.5) + " " + y + " A " + (w*0.5) + " " + (h*0.5) + " 0 0 1 " + (x+w*0.5) + " " + (y+h) + " L " + x + " " + (y+h) + " Z",
                  {fill: "#ffffff", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})
               // OR gate: shield shape -- concave curved back, pointed convex front.
               const mkOrGate = (x,y,w,h) => new fabric.Path(
                  "M " + x + " " + (y+h*0.15) + " Q " + (x+w*0.3) + " " + (y+h*0.5) + " " + x + " " + (y+h*0.85) +
                  " Q " + (x+w*0.55) + " " + (y+h*0.85) + " " + (x+w) + " " + (y+h*0.5) +
                  " Q " + (x+w*0.55) + " " + (y+h*0.15) + " " + x + " " + (y+h*0.15) + " Z",
                  {fill: "#ffffff", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})

               // ── HEADER + TOOLBAR ─────────────────────────────────────
               // brand teal #128BAB, Gill Sans/Calibri sans-serif chrome font
               // (monospace is reserved for code/register/diagram content).
               let hdr_box  = new fabric.Rect({left: 0, top: 0, width: 1080, height: 36, fill: "#ffffff", selectable: false, evented: false})
               let hdr_ttl  = new fabric.Text("ARM(LEGv8) Single-Cycle CPU Core", {left: 400, top: 7, fontSize: 20, fill: "#128BAB", fontWeight: 700, fontFamily: "Gill Sans, Calibri, sans-serif", selectable: false, evented: false})
               let tbar_box = new fabric.Rect({left: 0, top: 36, width: 1080, height: 28, fill: "#128BAB", selectable: false, evented: false})
               let tbar_txt = new fabric.Text("Execution Mode: Single-Cycle    Instructions: ADD SUB ADDI SUBI LDUR STUR B CBZ CBNZ", {left: 15, top: 43, fontSize: 12, fill: "#ffffff", fontFamily: "Gill Sans, Calibri, sans-serif", selectable: false, evented: false})

               // ── CODE EDITOR (left) ───────────────────────────────────
               let ed_box = new fabric.Rect({left: 10, top: 72, width: 460, height: 210, fill: "#0a1930", stroke: "#233", strokeWidth: 1, selectable: false, evented: false})
               let ed_hl  = new fabric.Rect({left: 12, top: 80, width: 456, height: 19, fill: "#b5652f", selectable: false, evented: false})
               const ROM = [
                  ["ADDI", "X1,X0,#10",     "0x00 91002801"],
                  ["ADDI", "X2,X0,#20",     "0x04 91005042"],
                  ["ADD ", "X3,X1,X2",      "0x08 8B020023"],
                  ["SUB ", "X4,X2,X1",      "0x0C CB010044"],
                  ["SUBI", "X6,X2,#5",      "0x10 D1001446"],
                  ["STUR", "X3,(X0,#0)",    "0x14 F8000003"],
                  ["LDUR", "X5,(X0,#0)",    "0x18 F8400005"],
                  ["CBZ ", "X1,#2",         "0x1C B4000041"],
                  ["CBNZ", "X4,#-3",        "0x20 B5FFFFA4"],
                  ["B   ", "#0",            "0x24 14000000"]
               ]
               let edRows = {}
               ROM.forEach((row, i) => {
                  edRows["ed_num_" + i] = mkTxt(18, 82 + i * 19, String(i + 1).padStart(2, " "), 11, "#5a6b8c", false)
                  edRows["ed_txt_" + i] = mkTxt(42, 82 + i * 19, row[0] + " " + row[1], 11, "#e6edf3", false)
                  edRows["ed_hex_" + i] = mkTxt(230, 82 + i * 19, row[2], 9, "#4a5568", false)
               })

               // ── CPU LOG (right) ──────────────────────────────────────
               let log_box = new fabric.Rect({left: 480, top: 72, width: 590, height: 210, fill: "#161b22", stroke: "#233", strokeWidth: 1, selectable: false, evented: false})
               let log_lbl = mkTxt(487, 76, "CPU Log", 11, "#8b949e", true)
               let log_txt = new fabric.Textbox("", {left: 487, top: 98, width: 575, fontSize: 11, fill: "#c9d1d9", fontFamily: "monospace", selectable: false, evented: false})

               // ── REGISTER GRID ────────────────────────────────────────
               let rg_box = new fabric.Rect({left: 10, top: 292, width: 1060, height: 64, fill: "#161b22", stroke: "#233", strokeWidth: 1, selectable: false, evented: false})
               const REGNAMES = ["PC", "X0", "X1", "X2", "X3", "X4", "X5", "X6", "Z", "PCSrc"]
               let rgCells = {}
               REGNAMES.forEach((nm, i) => {
                  let cx = 20 + i * 104
                  rgCells["rg_cell_" + i] = new fabric.Rect({left: cx, top: 302, width: 98, height: 44, fill: "#0d1117", stroke: "#128BAB", strokeWidth: 1, rx: 3, ry: 3, selectable: false, evented: false})
                  rgCells["rg_lbl_" + i]  = mkTxt(cx + 8, 306, nm, 10, "#128BAB", true)
                  rgCells["rg_val_" + i]  = mkTxt(cx + 8, 322, "0x0", 8, "#e6edf3", false)
               })

               // ── DATAPATH CARD ─────────────────────────────────────────
               let dp_box = new fabric.Rect({left: 10, top: 366, width: 1060, height: 380, fill: "#eef1f6", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})

               let boxes = {
                  pc_box:      mkBox(25, 515, 44, 55),
                  pc4_box:     mkAdd(25, 395, 44, 28),
                  imem_box:    mkBox(110, 495, 110, 105),
                  regs_box:    mkBox(310, 470, 110, 150),
                  signext_box: mkBox(310, 650, 110, 42),
                  alu_box:     mkALU(540, 480, 100, 115),
                  shift_box:   mkBox(460, 650, 66, 38),
                  branch_box:  mkAdd(545, 650, 50, 48),
                  datamem_box: mkBox(700, 480, 110, 115),
                  // Enlarged so the 8 real control-signal names can be
                  // listed inside it, each one the literal origin of its wire.
                  ctrl_ellipse: new fabric.Ellipse({left: 80, top: 383, rx: 58, ry: 45, fill: "#dce9f5", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false}),
                  // Tucked just above the ALU (clear of the control-signal
                  // ribbon which runs at y<=455, well above this at y>=458).
                  alucontrol_ellipse: new fabric.Ellipse({left: 545, top: 436, rx: 30, ry: 11, fill: "#dce9f5", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})
               }
               let muxes = {
                  reg2locmux:  mkTrap([{x:245,y:513},{x:245,y:537},{x:267,y:529},{x:267,y:521}]),
                  alusrcmux:   mkTrap([{x:460,y:513},{x:460,y:563},{x:490,y:550},{x:490,y:526}]),
                  memtoregmux: mkTrap([{x:860,y:495},{x:860,y:565},{x:890,y:548},{x:890,y:512}]),
                  pcsrcmux:    mkTrap([{x:960,y:555},{x:960,y:655},{x:992,y:635},{x:992,y:575}])
               }
               // Branch-decision logic: pc_src = UncondBr || (BranchZ && Zero)
               // || (BranchNZ && !Zero) -- drawn as real AND/OR gates instead
               // of leaving it implicit, so the diagram matches the actual
               // combinational logic in the design.
               let gates = {
                  gate_and1: mkAndGate(900, 400, 18, 16),
                  gate_and2: mkAndGate(900, 420, 18, 16),
                  gate_or:   mkOrGate(938, 414, 18, 26),
                  not_bubble: new fabric.Circle({left: 894.5, top: 429.5, radius: 2.5, fill: "#eef1f6", stroke: "#555555", strokeWidth: 1, selectable: false, evented: false})
               }
               let wires = {
                  w_pc_imem:              mkLine(69,542,110,542),
                  w_pc_pc4:               mkLine(50,515,50,423),
                  w_pc4_pcsrcmux:         mkPoly([{x:69,y:409},{x:69,y:378},{x:925,y:378},{x:925,y:575},{x:960,y:575}]),
                  w_pc_branch:            mkPoly([{x:90,y:542},{x:90,y:660},{x:545,y:660}]),
                  w_imem_rn:              mkLine(220,505,310,505),
                  w_imem_rm2:             mkLine(220,517,245,517),
                  w_imem_rd_reg2loc:      mkLine(220,533,245,533),
                  w_reg2locmux_regs:      mkLine(267,525,310,525),
                  w_imem_rd:              mkLine(220,545,310,545),
                  w_imem_signext:         mkPoly([{x:165,y:600},{x:165,y:671},{x:310,y:671}]),
                  w_regs_rd1_alu:         mkLine(420,505,549,505),
                  w_regs_rd2_alusrcmux:   mkLine(420,520,460,520),
                  w_signext_alusrcmux:    mkPoly([{x:420,y:671},{x:445,y:671},{x:445,y:558},{x:460,y:558}]),
                  w_alusrcmux_alu:        mkLine(490,538,560,538),
                  w_alu_datamem:          mkLine(624,500,700,500),
                  w_regs_to_datamem:      mkPoly([{x:420,y:525},{x:440,y:525},{x:440,y:610},{x:690,y:610},{x:690,y:533},{x:700,y:533}]),
                  w_datamem_to_memtoregmux: mkLine(811,520,860,520),
                  w_alu_to_memtoregmux:   mkPoly([{x:641,y:538},{x:657,y:538},{x:657,y:472},{x:855,y:472},{x:855,y:510},{x:860,y:510}]),
                  w_memtoregmux_writeback: mkPoly([{x:890,y:532},{x:920,y:532},{x:920,y:466},{x:230,y:466},{x:230,y:565},{x:310,y:565}]),
                  w_signext_shift:        mkLine(420,675,460,675),
                  w_shift_branchadder:    mkLine(526,675,545,675),
                  w_branchadder_pcsrcmux: mkPoly([{x:595,y:674},{x:700,y:674},{x:700,y:635},{x:960,y:635}]),
                  // Zero-flag trunk now stops at the AND-gate cluster instead
                  // of running straight to the mux -- it forks into both
                  // gates from there (see zero_to_and1/2 below).
                  w_zero_flag:            mkPoly([{x:590,y:480},{x:590,y:462},{x:897,y:462}]),
                  w_pcsrcmux_to_pc:       mkPoly([{x:992,y:605},{x:1030,y:605},{x:1030,y:372},{x:47,y:372},{x:47,y:515}]),

                  // ── Branch-decision gate wiring: pc_src = UncondBr ||
                  // (BranchZ && Zero) || (BranchNZ && !Zero), drawn as real
                  // AND/OR gates rather than left implicit.
                  zero_to_and1: mkPoly([{x:891,y:460},{x:891,y:414},{x:900,y:414}]),
                  zero_to_and2: mkPoly([{x:897,y:460},{x:897,y:434}]),
                  and1_to_or:   mkPoly([{x:918,y:408},{x:930,y:408},{x:930,y:425},{x:941,y:425}]),
                  and2_to_or:   mkLine(918,428,940,428),
                  or_to_pcsrcmux: mkPoly([{x:956,y:427},{x:970,y:427},{x:970,y:560}]),

                  // ── Control-signal wires (dashed), each one originating
                  // directly from its named label inside the Control ellipse
                  // and running to the exact block it drives. UncondBr/
                  // BranchZ/BranchNZ now feed the gate cluster above instead
                  // of the mux directly. Mux targets land exactly on that
                  // mux's actual vertical edge (not an arbitrary x that
                  // falls short of its slanted top edge).
                  c_uncondbr: mkPoly([{x:196,y:397},{x:933,y:397},{x:933,y:422},{x:940,y:422}]),
                  c_branchz:  mkLine(196,404,900,404),
                  c_branchnz: mkPoly([{x:196,y:411},{x:895,y:411},{x:895,y:424},{x:900,y:424}]),
                  c_memread:  mkPoly([{x:196,y:418},{x:730,y:418},{x:730,y:480}]),
                  c_memtoreg: mkPoly([{x:196,y:425},{x:870,y:425},{x:870,y:499}]),
                  c_memwrite: mkPoly([{x:196,y:434},{x:780,y:434},{x:780,y:480}]),
                  c_aluop:    mkPoly([{x:196,y:443},{x:510,y:443},{x:510,y:450},{x:545,y:450}]),
                  c_reg2loc:  mkPoly([{x:196,y:450},{x:255,y:450},{x:255,y:515}]),
                  c_alusrc:   mkPoly([{x:196,y:457},{x:475,y:457},{x:475,y:515}]),
                  c_regwrite: mkPoly([{x:196,y:462},{x:365,y:462},{x:365,y:470}])
               }
               wires.w_zero_flag.set({strokeDashArray: [4,3]})
               wires.w_pcsrcmux_to_pc.set({strokeWidth: 1.6})
               ;["c_reg2loc","c_alusrc","c_aluop","c_memread","c_memwrite","c_memtoreg","c_regwrite","c_uncondbr","c_branchz","c_branchnz",
                 "zero_to_and1","zero_to_and2","and1_to_or","and2_to_or","or_to_pcsrcmux"].forEach(k => wires[k].set({strokeDashArray: [3,2]}))

               let labels = {
                  lbl_pc:       mkTxt(35,536,"PC",10,"#222222",true),
                  lbl_pc4:      mkTxt(28,404,"PC+4",7,"#222222",false),
                  lbl_imem:     mkTxt(122,500,"Instruction",8,"#222222",true),
                  lbl_imem2:    mkTxt(122,512,"Memory(imem)",8,"#222222",true),
                  lbl_ctrl:     mkTxt(118,388,"Control",9,"#222222",true),
                  lbl_regs:     mkTxt(340,476,"Registers",9,"#222222",true),
                  lbl_rreg1:    mkTxt(316,503,"Read reg1",6,"#444444",false),
                  lbl_rreg2:    mkTxt(316,523,"Read reg2",6,"#444444",false),
                  lbl_wreg:     mkTxt(316,543,"Write reg",6,"#444444",false),
                  lbl_wdata:    mkTxt(316,562,"Write data",6,"#444444",false),
                  lbl_rdata1:   mkTxt(378,500,"Read data1",6,"#444444",false),
                  lbl_rdata2:   mkTxt(378,520,"Read data2",6,"#444444",false),
                  lbl_signext:  mkTxt(320,663,"Sign-extend",7,"#222222",true),
                  lbl_alu:      mkTxt(575,490,"ALU",11,"#222222",true),
                  lbl_shift:    mkTxt(465,663,"Shift left 2",6,"#222222",true),
                  lbl_add:      mkTxt(560,668,"Add",8,"#222222",true),
                  lbl_datamem:  mkTxt(715,486,"Data Memory(dmem)",8,"#222222",true),
                  lbl_addr:     mkTxt(706,499,"Address",6,"#444444",false),
                  lbl_wrdata:   mkTxt(706,530,"Write data",6,"#444444",false),
                  lbl_rddata:   mkTxt(772,513,"Read data",6,"#444444",false),
                  lbl_reg2loc:  mkTxt(232,492,"Reg2Loc Mux",6,"#222222",false),
                  lbl_alucontrol: mkTxt(555,445,"ALU control",5,"#222222",true),
                  lbl_mux1:     mkTxt(450,492,"ALUSrc Mux",6,"#222222",false),
                  lbl_mux2:     mkTxt(858,485,"MemToReg Mux",6,"#222222",false),
                  lbl_mux3:     mkTxt(954,543,"PCSrc Mux",6,"#222222",false),
                  lbl_zero:     mkTxt(555,470,"Zero flag",6,"#8a6d3b",false),
               }

               let dyn = {
                  pc_val:      mkTxt(34,575,"0x0",8,"#0969da",true),
                  imem_val:    mkTxt(130,546,"0x00000000",7,"#333333",false),
                  // Each of these IS the labeled origin of its control wire
                  // (c_reg2loc, c_uncondbr, ...) inside the Control ellipse --
                  // brightens to CTRL_ON when that bit is asserted this cycle.
                  ctrl_lbl_uncondbr: mkTxt(120,397,"UncondBr",6,"#555555",false),
                  ctrl_lbl_branchz:  mkTxt(120,404,"BranchZ",6,"#555555",false),
                  ctrl_lbl_branchnz: mkTxt(120,411,"BranchNZ",6,"#555555",false),
                  ctrl_lbl_memread:  mkTxt(120,418,"MemRead",6,"#555555",false),
                  ctrl_lbl_memtoreg: mkTxt(120,425,"MemToReg",6,"#555555",false),
                  ctrl_lbl_memwrite: mkTxt(120,432,"MemWrite",6,"#555555",false),
                  ctrl_lbl_aluop:    mkTxt(120,439,"ALUOp",6,"#555555",false),
                  ctrl_lbl_reg2loc:  mkTxt(120,446,"Reg2Loc",6,"#555555",false),
                  ctrl_lbl_alusrc:   mkTxt(120,453,"ALUSrc",6,"#555555",false),
                  ctrl_lbl_regwrite: mkTxt(120,460,"RegWrite",6,"#555555",false),
                  alu_op:      mkTxt(568,530,"0 op 0",8,"#0969da",false),
                  alu_result:  mkTxt(568,548,"= 0",9,"#1a7f37",true),
                  alu_zero_txt:mkTxt(568,564,"Zero=0",7,"#555555",false),
                  datamem_op:  mkTxt(706,568,"--",7,"#555555",false),
                  pcsrc_sel:   mkTxt(936,612,"sel=0",7,"#555555",false)
               }

               // ── STATUS bar ────────────────────────────────────────────
               let status_box  = new fabric.Rect({left: 10, top: 756, width: 1060, height: 64, fill: "#161b22", stroke: "#233", strokeWidth: 1, selectable: false, evented: false})
               let status_str  = mkTxt(23,762,"-- RESET --",13,"#a371f7",true)
               let status_str2 = mkTxt(23,782,"",10,"#8b949e",false)
               let status_str3 = mkTxt(23,798,"",11,"#e3b341",true)

               return Object.assign({
                  hdr_box, hdr_ttl, tbar_box, tbar_txt,
                  ed_box, ed_hl, log_box, log_lbl, log_txt,
                  rg_box, dp_box,
                  status_box, status_str, status_str2, status_str3
               }, edRows, rgCells, boxes, muxes, gates, wires, labels, dyn)
            },
            render() {
               const h = (v, w) => "0x" + BigInt.asUintN(64, BigInt(v)).toString(16).toUpperCase().padStart(w, "0")
               const ACTIVE = "#ff8c00", ACTIVEW = 2.5, INACTIVE = "#c9d2de", INACTIVEW = 1.2
               const WON = "#e8590c"
               const CTRL_ON = "#ffb454", CTRL_OFF = "#e8ddc0"

               // 64-bit signals must use asBigInt() -- asInt() throws once a signal
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
               let reg2_loc  = '$reg2_loc'.asBool(false)
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

               let x1 = '/xreg[1]$val'.asBigInt(0n)
               let x2 = '/xreg[2]$val'.asBigInt(0n)
               let x3 = '/xreg[3]$val'.asBigInt(0n)
               let x4 = '/xreg[4]$val'.asBigInt(0n)
               let x5 = '/xreg[5]$val'.asBigInt(0n)
               let x6 = '/xreg[6]$val'.asBigInt(0n)
               let m0 = '/dmem[0]$val'.asBigInt(0n)

               const NAMES = ["ADDI X1,X0,#10", "ADDI X2,X0,#20", "ADD X3,X1,X2",
                              "SUB X4,X2,X1", "SUBI X6,X2,#5", "STUR X3,(X0,#0)", "LDUR X5,(X0,#0)",
                              "CBZ X1,#2", "CBNZ X4,#-3", "B #0"]
               let idx = Math.min(Math.floor(Number(pc) / 4), 9)
               let name = NAMES[idx] || "?"
               let tstr = is_r ? "R" : is_i ? "I" : is_d ? "D" : is_b ? "B" : is_cb ? "CB" : "?"
               let aop  = (is_r || is_i || is_ldur || is_stur) ? (is_d ? "addr+" : "op") : "--"

               // ── Datapath-usage booleans (drive per-cycle highlighting) ──
               let usesRegs         = !is_b
               let usesRegRead2ToALU= is_r || is_cb
               let usesRegRead2ToMem= is_stur
               let usesSignExt      = is_i || is_d || is_b || is_cb
               let usesALU          = !is_b
               let usesALUAddr      = is_d
               let usesMemRead      = is_ldur
               let writeBackFromALU = reg_write && !mem_to_reg
               let usesWriteBack    = reg_write
               let usesBranchCalc   = is_b || is_cb
               let usesZeroCheck    = is_cb

               let objs = this.getObjects()

               // Code editor: highlight current line, CPU log: recent history.
               objs.ed_hl.set({top: 80 + idx * 19})
               let hist = NAMES.slice(Math.max(0, idx - 5), idx + 1).join("  |  ")
               objs.log_txt.set({text: hist})

               // Register grid: PC, X0-X6, Zero flag, PCSrc.
               const regRow = [pc, 0n, x1, x2, x3, x4, x5, x6]
               for (let i = 0; i < 8; i++) {
                  objs["rg_val_" + i].set({text: h(regRow[i], i === 0 ? 4 : 16)})
               }
               objs["rg_val_8"].set({text: alu_zero ? "1" : "0"})
               objs["rg_val_9"].set({text: pc_src ? "1 (taken)" : "0"})

               // Datapath dynamic labels.
               objs.pc_val.set({text: h(pc, 4)})
               objs.imem_val.set({text: h(instr, 8)})
               objs.alu_op.set({text: usesALU ? (alu_in1 + " " + aop + " " + alu_in2) : "--"})
               objs.alu_result.set({text: usesALU ? ("= " + alu_res_v) : "--"})
               objs.alu_zero_txt.set({text: "Zero=" + (alu_zero?1:0)})
               objs.datamem_op.set({text: mem_write ? ("WRITE @" + alu_res_v) : mem_read ? ("READ @" + alu_res_v) : "--"})
               objs.pcsrc_sel.set({text: "sel=" + (pc_src?1:0)})

               // ── Box border highlighting ──────────────────────────────
               const setBox = (obj, on) => obj.set({stroke: on ? ACTIVE : "#555555", strokeWidth: on ? 2.5 : 1})
               setBox(objs.pc_box, true)
               setBox(objs.pc4_box, true)
               setBox(objs.imem_box, true)
               setBox(objs.ctrl_ellipse, true)
               setBox(objs.alucontrol_ellipse, usesALU)
               setBox(objs.regs_box, usesRegs)
               setBox(objs.reg2locmux, usesRegs)
               setBox(objs.signext_box, usesSignExt)
               setBox(objs.alu_box, usesALU)
               setBox(objs.shift_box, usesBranchCalc)
               setBox(objs.branch_box, usesBranchCalc)
               setBox(objs.datamem_box, usesALUAddr)
               setBox(objs.alusrcmux, usesALU)
               setBox(objs.memtoregmux, usesWriteBack)
               setBox(objs.pcsrcmux, true)

               // ── Wire highlighting ────────────────────────────────────
               const setWire = (obj, on) => obj.set({stroke: on ? ACTIVE : INACTIVE, strokeWidth: on ? ACTIVEW : INACTIVEW})
               setWire(objs.w_pc_imem, true)
               setWire(objs.w_pc_pc4, true)
               setWire(objs.w_imem_rn, usesRegs)
               setWire(objs.w_imem_rm2, usesRegs)
               setWire(objs.w_imem_rd_reg2loc, usesRegs)
               setWire(objs.w_reg2locmux_regs, usesRegs)
               setWire(objs.w_imem_rd, reg_write)
               setWire(objs.w_imem_signext, usesSignExt)
               setWire(objs.w_regs_rd1_alu, usesALU)
               setWire(objs.w_regs_rd2_alusrcmux, usesRegRead2ToALU)
               setWire(objs.w_signext_alusrcmux, is_i || is_d)
               setWire(objs.w_alusrcmux_alu, usesALU)
               setWire(objs.w_alu_datamem, usesALUAddr)
               setWire(objs.w_regs_to_datamem, usesRegRead2ToMem)
               setWire(objs.w_datamem_to_memtoregmux, usesMemRead)
               setWire(objs.w_alu_to_memtoregmux, writeBackFromALU)
               setWire(objs.w_memtoregmux_writeback, usesWriteBack)
               setWire(objs.w_pc_branch, usesBranchCalc)
               setWire(objs.w_signext_shift, usesBranchCalc)
               setWire(objs.w_shift_branchadder, usesBranchCalc)
               setWire(objs.w_branchadder_pcsrcmux, usesBranchCalc)
               objs.w_zero_flag.set({stroke: usesZeroCheck ? CTRL_ON : CTRL_OFF, strokeWidth: usesZeroCheck ? 1.6 : 1})

               // ── Control-signal wires: bright when that control bit is
               // actually asserted this cycle, dim otherwise.
               const setCtrl = (obj, on) => obj.set({stroke: on ? CTRL_ON : CTRL_OFF, strokeWidth: on ? 1.6 : 1})
               setCtrl(objs.c_reg2loc, reg2_loc)
               setCtrl(objs.c_alusrc, alu_src)
               setCtrl(objs.c_aluop, usesALU)
               setCtrl(objs.c_memread, mem_read)
               setCtrl(objs.c_memwrite, mem_write)
               setCtrl(objs.c_memtoreg, mem_to_reg)
               setCtrl(objs.c_regwrite, reg_write)
               setCtrl(objs.c_uncondbr, uncond_br)
               setCtrl(objs.c_branchz, branch_z)
               setCtrl(objs.c_branchnz, branch_nz)

               // ── Branch-decision gates: pc_src = UncondBr || (BranchZ &&
               // Zero) || (BranchNZ && !Zero) -- each AND term lights up only
               // when it is genuinely true this cycle, not just when its
               // instruction type is active.
               let and1_true = branch_z && alu_zero
               let and2_true = branch_nz && !alu_zero
               setCtrl(objs.zero_to_and1, branch_z)
               setCtrl(objs.zero_to_and2, branch_nz)
               setCtrl(objs.and1_to_or, and1_true)
               setCtrl(objs.and2_to_or, and2_true)
               setCtrl(objs.or_to_pcsrcmux, pc_src)
               const setGate = (obj, on) => obj.set({stroke: on ? ACTIVE : "#555555", strokeWidth: on ? 2 : 1})
               setGate(objs.gate_and1, and1_true)
               setGate(objs.gate_and2, and2_true)
               setGate(objs.gate_or, pc_src)

               // The signal names themselves (inside the Control ellipse)
               // brighten right along with the wires they originate.
               const setCtrlLabel = (obj, on) => obj.set({fill: on ? CTRL_ON : "#555555", fontWeight: on ? 700 : 400})
               setCtrlLabel(objs.ctrl_lbl_reg2loc, reg2_loc)
               setCtrlLabel(objs.ctrl_lbl_uncondbr, uncond_br)
               setCtrlLabel(objs.ctrl_lbl_branchz, branch_z)
               setCtrlLabel(objs.ctrl_lbl_branchnz, branch_nz)
               setCtrlLabel(objs.ctrl_lbl_memread, mem_read)
               setCtrlLabel(objs.ctrl_lbl_memtoreg, mem_to_reg)
               setCtrlLabel(objs.ctrl_lbl_memwrite, mem_write)
               setCtrlLabel(objs.ctrl_lbl_alusrc, alu_src)
               setCtrlLabel(objs.ctrl_lbl_aluop, usesALU)
               setCtrlLabel(objs.ctrl_lbl_regwrite, reg_write)

               // The two PCSrc-mux inputs: highlight whichever one actually won.
               objs.w_pc4_pcsrcmux.set({stroke: pc_src ? INACTIVE : WON, strokeWidth: pc_src ? INACTIVEW : ACTIVEW})
               if (usesBranchCalc) {
                  objs.w_branchadder_pcsrcmux.set({stroke: pc_src ? WON : INACTIVE, strokeWidth: pc_src ? ACTIVEW : INACTIVEW})
               }
               objs.w_pcsrcmux_to_pc.set({stroke: WON, strokeWidth: 2})

               objs.status_str.set({text: name})
               objs.status_str2.set({text: "PC=" + h(pc,4) + "  instr=" + h(instr,8) + "  format=" + tstr + "  next_pc=" + h(pc_src ? br_tgt : pc + 4n, 4) + (pc_src ? "  [BRANCH TAKEN]" : "  [SEQUENTIAL]")})
               objs.status_str3.set({text: (x5 === 30n) ? "PASS -- X5 == 30 (LDUR loaded the value STUR stored from X3)" : "X5 = " + x5 + "  (waiting for X5 == 30)"})
               objs.status_str3.set({fill: (x5 === 30n) ? "#3fb950" : "#e3b341"})
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
