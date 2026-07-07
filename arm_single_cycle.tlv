\m4_TLV_version 1d: tl-x.org
\SV
   // ═══════════════════════════════════════════════════════════════════
   //  ARM Single-Cycle Processor — Prof. Kamal ISA
   //  9 Instructions: ADD  SUB  ADDI  SUBI  LDUR  STUR  B  CBZ  CBNZ
   //
   //  Test Program (inline ROM):
   //    0x00: ADDI X1, X0, #10    → X1 = 10
   //    0x04: ADDI X2, X0, #20    → X2 = 20
   //    0x08: ADD  X3, X1, X2     → X3 = 30
   //    0x0C: SUB  X4, X2, X1     → X4 = 10
   //    0x10: STUR X3, [X0, #0]   → Mem[0] = 30
   //    0x14: LDUR X5, [X0, #0]   → X5 = 30  ← PASS condition
   //    0x18: CBZ  X1, #2         → not taken  (X1=10≠0)
   //    0x1C: CBNZ X4, #-3        → TAKEN      (X4=10≠0) → 0x10
   //    0x20: B    #0             → infinite loop
   //
   //  Waveform signals to watch (add in Makerchip waveform panel):
   //    |cpu @0  $pc, $instr, $is_r_type, $is_i_type, $is_d_type,
   //             $is_b_type, $is_cb_type, $reg_write, $alu_src,
   //             $mem_read, $mem_write, $mem_to_reg, $branch_z,
   //             $branch_nz, $uncond_br, $pc_src, $alu_result,
   //             $alu_zero, $wr_data
   //    /xreg[1..5] $val   — register file values
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
         //  PROGRAM COUNTER
         // ─────────────────────────────────────────────────────────
         $pc[63:0] =
            $reset            ? 64'b0             :
            >>1$pc_src        ? >>1$branch_target :
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
            ($pc[6:2] == 5'd4) ? 32'hF8000003 :  // STUR X3, [X0, #0]
            ($pc[6:2] == 5'd5) ? 32'hF8400005 :  // LDUR X5, [X0, #0]
            ($pc[6:2] == 5'd6) ? 32'hB4000041 :  // CBZ  X1, #2
            ($pc[6:2] == 5'd7) ? 32'hB5FFFFA4 :  // CBNZ X4, #-3
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
            $val[63:0] = |cpu$reset ? 64'b0 :
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
            $val[63:0] = |cpu$reset ? 64'b0 :
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
         //  Paste this entire \viz_js block into Makerchip and the
         //  IDE will render the animated datapath alongside your code.
         //
         //  Colour key:
         //    Blue   (#388bfd) — data / address buses
         //    Green  (#3fb950) — register writes / load results
         //    Amber  (#e3b341) — immediates / branch paths
         //    Purple (#a371f7) — control signals
         //    Red    (#f85149) — memory stores
         // ═════════════════════════════════════════════════════════
         \viz_js
            box = {
               width:  1100,
               height: 680,
               viewbox: "0 0 1100 680",
               title:  "ARM CPU — Prof. Kamal ISA"
            }
            //
            svg_body = `
            <style>
               .lbl {font-family:monospace;font-size:11px;dominant-baseline:central;text-anchor:middle}
               .val {font-family:monospace;font-size:9px; dominant-baseline:central;text-anchor:middle}
               .sig {font-family:monospace;font-size:8px; dominant-baseline:central;text-anchor:middle}
            </style>

            <!-- BACKGROUND -->
            <rect width="1100" height="680" fill="#0d1117"/>

            <!-- ── GHOST WIRES (always visible, dim) ─────────── -->
            <path d="M90,310 L140,310"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M60,290 L60,96 L140,96"                            fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M186,96 L68,96 L55,105"                            fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M246,130 L68,130 L55,120"                          fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M50,112 L8,112 L8,310 L30,310"                     fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M175,278 L175,75 L295,75"                          fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M210,310 L295,310"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M175,375 L175,440 L265,440"                        fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M385,440 L500,440 L500,368"                        fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M425,300 L508,300"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M425,330 L495,330"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M515,342 L540,342"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M630,315 L688,315"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M778,315 L818,315"                                  fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M630,330 L655,330 L655,228 L808,228 L818,290"      fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M838,305 L858,305 L858,225 L365,225 L365,272"      fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M65,290 L65,134 L198,134"                          fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>
            <path d="M175,278 L175,150 L198,150"                        fill="none" stroke="#2a3040" stroke-width="1" stroke-dasharray="3,3"/>

            <!-- ── ACTIVE WIRES (driven by render()) ─────────── -->
            <!-- Arrow markers for each colour -->
            <defs>
               <marker id="arB" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
                  <path d="M1 1L9 5L1 9" fill="none" stroke="#388bfd" stroke-width="1.5" stroke-linecap="round"/></marker>
               <marker id="arG" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
                  <path d="M1 1L9 5L1 9" fill="none" stroke="#3fb950" stroke-width="1.5" stroke-linecap="round"/></marker>
               <marker id="arA" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
                  <path d="M1 1L9 5L1 9" fill="none" stroke="#e3b341" stroke-width="1.5" stroke-linecap="round"/></marker>
               <marker id="arP" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
                  <path d="M1 1L9 5L1 9" fill="none" stroke="#a371f7" stroke-width="1.5" stroke-linecap="round"/></marker>
               <marker id="arR" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
                  <path d="M1 1L9 5L1 9" fill="none" stroke="#f85149" stroke-width="1.5" stroke-linecap="round"/></marker>
            </defs>

            <path id="w_pc_imem"    d="M90,310 L140,310"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_pc_add4"    d="M60,290 L60,96 L140,96"                             fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_add4_pcmux" d="M186,96 L68,96 L55,105"                             fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_br_pcmux"   d="M246,130 L68,130 L55,120"                           fill="none" stroke="none" stroke-width="2" marker-end="url(#arA)"/>
            <path id="w_pcmux_pc"   d="M50,112 L8,112 L8,310 L30,310"                      fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_imem_ctrl"  d="M175,278 L175,75 L295,75"                           fill="none" stroke="none" stroke-width="2" marker-end="url(#arP)"/>
            <path id="w_imem_rf"    d="M210,310 L295,310"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arP)"/>
            <path id="w_imem_sx"    d="M175,375 L175,440 L265,440"                         fill="none" stroke="none" stroke-width="2" marker-end="url(#arA)"/>
            <path id="w_sx_amux"    d="M385,440 L500,440 L500,368"                         fill="none" stroke="none" stroke-width="2" marker-end="url(#arA)"/>
            <path id="w_rf_alu1"    d="M425,300 L508,300"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arG)"/>
            <path id="w_rf_amux"    d="M425,330 L495,330"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arG)"/>
            <path id="w_amux_alu"   d="M515,342 L540,342"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_alu_dmem"   d="M630,315 L688,315"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_stur_data"  d="M425,342 L460,355 L688,340"                         fill="none" stroke="none" stroke-width="2" marker-end="url(#arR)"/>
            <path id="w_dmem_wmux"  d="M778,315 L818,315"                                   fill="none" stroke="none" stroke-width="2" marker-end="url(#arG)"/>
            <path id="w_alu_wmux"   d="M630,330 L655,330 L655,228 L808,228 L818,290"        fill="none" stroke="none" stroke-width="2" marker-end="url(#arB)"/>
            <path id="w_wmux_rf"    d="M838,305 L858,305 L858,225 L365,225 L365,272"        fill="none" stroke="none" stroke-width="2" marker-end="url(#arG)"/>
            <path id="w_pc_brad"    d="M65,290 L65,134 L198,134"                            fill="none" stroke="none" stroke-width="2" marker-end="url(#arA)"/>
            <path id="w_imem_brad"  d="M175,278 L175,150 L198,150"                          fill="none" stroke="none" stroke-width="2" marker-end="url(#arA)"/>

            <!-- Wire value labels (updated by render) -->
            <text id="lbl_pc_val"  x="115"  y="302" fill="none" font-family="monospace" font-size="8" text-anchor="middle">0x00</text>
            <text id="lbl_alu_res" x="666"  y="308" fill="none" font-family="monospace" font-size="8" text-anchor="middle">0</text>
            <text id="lbl_imm_val" x="330"  y="433" fill="none" font-family="monospace" font-size="8" text-anchor="middle">#0</text>
            <text id="lbl_wb_val"  x="612"  y="218" fill="none" font-family="monospace" font-size="8" text-anchor="middle">WB=0</text>
            <text id="lbl_br_tgt"  x="157"  y="120" fill="none" font-family="monospace" font-size="8" text-anchor="middle">target</text>

            <!-- ── COMPONENT BOXES ────────────────────────────── -->
            <!-- PC -->
            <g id="comp_pc">
               <rect x="30" y="290" width="60" height="40" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="60" y="306" fill="#8b949e">PC</text>
               <text id="v_pc" class="val" x="60" y="320" fill="#388bfd">0x0000</text>
            </g>

            <!-- PC Mux -->
            <g id="comp_pcmux">
               <rect x="48" y="104" width="18" height="28" rx="2" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="57" y="118" font-size="8" fill="#8b949e">M</text>
            </g>

            <!-- +4 Adder -->
            <g id="comp_add4">
               <rect x="140" y="84" width="46" height="24" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="163" y="96" fill="#8b949e">+4 ADD</text>
            </g>

            <!-- Branch Adder -->
            <g id="comp_brad">
               <rect x="198" y="120" width="48" height="44" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="222" y="136" fill="#8b949e">BR</text>
               <text class="lbl" x="222" y="150" fill="#8b949e">ADD</text>
            </g>

            <!-- Instruction Memory -->
            <g id="comp_imem">
               <rect x="140" y="270" width="70" height="110" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="175" y="300" fill="#8b949e">INSTR</text>
               <text class="lbl" x="175" y="314" fill="#8b949e">MEM</text>
               <text id="v_itype" class="val" x="175" y="336" fill="#a371f7">—</text>
               <text id="v_ihex"  class="val" x="175" y="350" fill="#555">0x00000000</text>
               <text id="v_iname" class="val" x="175" y="364" fill="#8b949e">—</text>
            </g>

            <!-- Control Unit -->
            <g id="comp_ctrl">
               <rect x="295" y="55" width="90" height="55" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="340" y="76"  fill="#8b949e">CONTROL</text>
               <text class="lbl" x="340" y="93"  fill="#8b949e">UNIT</text>
            </g>

            <!-- Register File -->
            <g id="comp_rf">
               <rect x="295" y="272" width="130" height="110" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="360" y="291" fill="#8b949e">REGISTER FILE</text>
               <text x="310" y="310" font-family="monospace" font-size="8" fill="#555">Rn[9:5]  → rs1</text>
               <text x="310" y="325" font-family="monospace" font-size="8" fill="#555">Rm/Rt    → rs2</text>
               <text x="310" y="340" font-family="monospace" font-size="8" fill="#555">Rd[4:0]  ← wb</text>
               <text x="310" y="357" font-family="monospace" font-size="8" fill="#555">X31=XZR  = 0</text>
               <text x="310" y="371" font-family="monospace" font-size="8" fill="#555">RegWrite = <tspan id="v_rw">0</tspan></text>
            </g>

            <!-- Sign Extend -->
            <g id="comp_sx">
               <rect x="265" y="425" width="120" height="30" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="325" y="440" fill="#8b949e">SIGN / ZERO EXT</text>
            </g>

            <!-- ALU Mux -->
            <g id="comp_amux">
               <rect x="495" y="316" width="20" height="56" rx="2" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="505" y="344" font-size="8" fill="#8b949e">M</text>
               <text id="v_alusrc" class="val" x="505" y="360" fill="#555">0</text>
            </g>

            <!-- ALU -->
            <g id="comp_alu">
               <rect x="540" y="272" width="90" height="95" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="585" y="295"  fill="#8b949e">ALU</text>
               <text id="v_aluop"  class="val" x="585" y="312" fill="#8b949e">— op —</text>
               <text id="v_alures" class="val" x="585" y="328" fill="#3fb950">= 0</text>
               <text id="v_aluz"   class="val" x="585" y="344" fill="#8b949e">Zero=0</text>
               <text id="v_aluin"  class="val" x="585" y="358" fill="#555">0 op 0</text>
            </g>

            <!-- Data Memory -->
            <g id="comp_dmem">
               <rect x="688" y="272" width="90" height="95" rx="4" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="733" y="300" fill="#8b949e">DATA</text>
               <text class="lbl" x="733" y="315" fill="#8b949e">MEM</text>
               <text id="v_dmop"   class="val" x="733" y="333" fill="#555">—</text>
               <text id="v_dmaddr" class="val" x="733" y="347" fill="#555">addr: —</text>
               <text id="v_dmval"  class="val" x="733" y="361" fill="#555">data: —</text>
            </g>

            <!-- WB Mux -->
            <g id="comp_wmux">
               <rect x="818" y="278" width="20" height="54" rx="2" fill="#161b22" stroke="#30363d" stroke-width="1"/>
               <text class="lbl" x="828" y="305" font-size="8" fill="#8b949e">M</text>
               <text id="v_mem2reg" class="val" x="828" y="320" fill="#555">0</text>
            </g>

            <!-- ── REGISTER FILE SIDEBAR ───────────────────────── -->
            <rect x="875" y="55" width="215" height="235" rx="6" fill="#161b22" stroke="#21262d" stroke-width="1"/>
            <text x="982" y="78" text-anchor="middle" font-family="monospace" font-size="11" fill="#8b949e">Register File</text>
            <line x1="880" y1="84" x2="1085" y2="84" stroke="#21262d" stroke-width="0.5"/>
            <text id="rf_x0" x="885" y="102"  font-family="monospace" font-size="11" fill="#444">X0  (XZR) =  0</text>
            <text id="rf_x1" x="885" y="120"  font-family="monospace" font-size="11" fill="#8b949e">X1          =  0</text>
            <text id="rf_x2" x="885" y="138"  font-family="monospace" font-size="11" fill="#8b949e">X2          =  0</text>
            <text id="rf_x3" x="885" y="156"  font-family="monospace" font-size="11" fill="#8b949e">X3          =  0</text>
            <text id="rf_x4" x="885" y="174"  font-family="monospace" font-size="11" fill="#8b949e">X4          =  0</text>
            <text id="rf_x5" x="885" y="192"  font-family="monospace" font-size="11" fill="#8b949e">X5          =  0</text>
            <line x1="880" y1="204" x2="1085" y2="204" stroke="#21262d" stroke-width="0.5"/>
            <text x="885" y="220" font-family="monospace" font-size="10" fill="#555">Data Memory</text>
            <text id="rf_m0" x="885" y="236" font-family="monospace" font-size="11" fill="#8b949e">Mem[0]      =  —</text>
            <text id="rf_m4" x="885" y="252" font-family="monospace" font-size="10" fill="#444">Mem[4]      =  —</text>
            <text id="rf_m8" x="885" y="268" font-family="monospace" font-size="10" fill="#444">Mem[8]      =  —</text>

            <!-- ── STATUS / INSTRUCTION PANEL ─────────────────── -->
            <rect x="10" y="590" width="1080" height="82" rx="5" fill="#161b22" stroke="#21262d" stroke-width="1"/>
            <text id="s_name" x="20" y="614" font-family="monospace" font-size="14" font-weight="bold" fill="#a371f7">— RESET —</text>
            <text id="s_type" x="20" y="634" font-family="monospace" font-size="11" fill="#8b949e">format: ?</text>
            <text id="s_pc"   x="20" y="650" font-family="monospace" font-size="10" fill="#555">pc: 0x0000   hex: 0x00000000   alu_result: 0   next_pc: 0x0004</text>

            <!-- Control signal badges -->
            <text x="480" y="614" font-family="monospace" font-size="10" fill="#555">─── CONTROL SIGNALS ───────────────────────────</text>
            <g id="b_rw">  <rect x="480" y="622" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="508" y="629" fill="#555">RegWr:0</text></g>
            <g id="b_as">  <rect x="540" y="622" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="568" y="629" fill="#555">ALUSrc:0</text></g>
            <g id="b_mr">  <rect x="600" y="622" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="628" y="629" fill="#555">MemRd:0</text></g>
            <g id="b_mw">  <rect x="660" y="622" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="688" y="629" fill="#555">MemWr:0</text></g>
            <g id="b_m2r"> <rect x="720" y="622" width="64" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="752" y="629" fill="#555">Mem2Reg:0</text></g>
            <g id="b_pcs"> <rect x="788" y="622" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="816" y="629" fill="#555">PCSrc:0</text></g>
            <g id="b_ub">  <rect x="480" y="640" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="508" y="647" fill="#555">UncBr:0</text></g>
            <g id="b_bz">  <rect x="540" y="640" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="568" y="647" fill="#555">BrZ:0</text></g>
            <g id="b_bnz"> <rect x="600" y="640" width="56" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="628" y="647" fill="#555">BrNZ:0</text></g>
            <g id="b_r2l"> <rect x="660" y="640" width="64" height="14" rx="3" fill="none" stroke="#333"/><text class="sig" x="692" y="647" fill="#555">Reg2Loc:0</text></g>
            `
            //
            render() {
               //─── Read all signals ─────────────────────────────
               let pc        = '$pc'         .asInt()
               let instr     = '$instr'      .asInt(16)
               let is_r      = '$is_r_type'  .asBool()
               let is_i      = '$is_i_type'  .asBool()
               let is_d      = '$is_d_type'  .asBool()
               let is_b      = '$is_b_type'  .asBool()
               let is_cb     = '$is_cb_type' .asBool()
               let is_ldur   = '$is_ldur'    .asBool()
               let is_stur   = '$is_stur'    .asBool()
               let is_addi   = '$is_addi'    .asBool()
               let is_subi   = '$is_subi'    .asBool()
               let is_add    = '$is_add'     .asBool()
               let is_sub    = '$is_sub'     .asBool()
               let reg_write = '$reg_write'  .asBool()
               let alu_src   = '$alu_src'    .asBool()
               let mem_read  = '$mem_read'   .asBool()
               let mem_write = '$mem_write'  .asBool()
               let mem_to_reg= '$mem_to_reg' .asBool()
               let uncond_br = '$uncond_br'  .asBool()
               let branch_z  = '$branch_z'   .asBool()
               let branch_nz = '$branch_nz'  .asBool()
               let reg2_loc  = '$reg2_loc'   .asBool()
               let pc_src    = '$pc_src'     .asBool()
               let alu_in1   = '$alu_in1'    .asInt()
               let alu_in2   = '$alu_in2'    .asInt()
               let alu_res   = '$alu_result' .asInt()
               let alu_zero  = '$alu_zero'   .asBool()
               let wr_data   = '$wr_data'    .asInt()
               let br_tgt    = '$branch_target'.asInt()
               let rd        = '$rd'         .asInt()

               // Register file and memory
               let x = [0]; for (let i=1;i<6;i++) x[i] = '/top|cpu/xreg['+i+']$val'.asInt()
               let m = []; for (let i=0;i<3;i++)  m[i] = '/top|cpu/dmem['+i+']$val'.asInt()

               //─── Helpers ──────────────────────────────────────
               const B='#388bfd', G='#3fb950', A='#e3b341', P='#a371f7', R='#f85149', GY='#8b949e'

               const h16 = (v,w=4) => '0x'+v.toString(16).toUpperCase().padStart(w,'0')

               const hiComp = (id, active, col) => {
                  let g = document.getElementById('comp_'+id); if(!g) return
                  let rect = g.querySelector('rect')
                  if (rect) { rect.setAttribute('stroke', active ? col : '#30363d')
                               rect.setAttribute('stroke-width', active ? '2' : '1')
                               rect.setAttribute('fill', active ? col.replace(')',', 0.08)').replace('#','rgba(0x').replace('rgba(0x','rgba(') : '#161b22') }
               }
               const hiWire = (id, col) => {
                  let el = document.getElementById('w_'+id); if(!el) return
                  el.setAttribute('stroke', col || 'none')
                  // match marker colour
                  let mc = col===G?'G':col===A?'A':col===P?'P':col===R?'R':'B'
                  if (col) el.setAttribute('marker-end','url(#ar'+mc+')')
               }
               const setTxt = (id, txt, col) => {
                  let el = document.getElementById(id); if(!el) return
                  if (txt !== undefined) el.textContent = txt
                  if (col !== undefined) el.setAttribute('fill', col)
               }
               const badge = (id, active, col, label) => {
                  let g = document.getElementById(id); if(!g) return
                  let r = g.querySelector('rect'), t = g.querySelector('text')
                  if (r) { r.setAttribute('fill', active ? col+'22' : 'none')
                           r.setAttribute('stroke', active ? col : '#333') }
                  if (t) { t.setAttribute('fill', active ? col : '#555')
                           if (label) t.textContent = label }
               }

               //─── Instruction name lookup ──────────────────────
               const NAMES = ['ADDI X1,X0,#10','ADDI X2,X0,#20','ADD X3,X1,X2',
                  'SUB X4,X2,X1','STUR X3,[X0,#0]','LDUR X5,[X0,#0]',
                  'CBZ X1,#2','CBNZ X4,#-3','B #0']
               let idx = Math.min(Math.floor(pc / 4), 8) % 9
               let name = NAMES[idx] || '?'
               let tstr = is_r?'R':is_i?'I':is_d?'D':is_b?'B':is_cb?'CB':'?'
               let aop  = (is_add||is_addi||is_ldur||is_stur)?'+':
                          (is_sub||is_subi)?'-':(is_cb)?'passB':'?'

               //─── Update value labels ──────────────────────────
               setTxt('v_pc', h16(pc), B)
               setTxt('v_itype', '['+tstr+'-format]', P)
               setTxt('v_ihex',  h16(instr,8))
               setTxt('v_iname', name, GY)
               setTxt('v_rw',    reg_write?'1':'0', reg_write?G:GY)
               setTxt('v_alusrc',alu_src?'imm':'rf', alu_src?A:GY)
               setTxt('v_aluop', aop+' op', GY)
               setTxt('v_alures','= '+alu_res, alu_zero?A:G)
               setTxt('v_aluz',  'Zero='+( alu_zero?1:0), alu_zero?A:GY)
               setTxt('v_aluin', alu_in1+' '+aop+' '+alu_in2, GY)
               setTxt('v_mem2reg', mem_to_reg?'ld':'alu', mem_to_reg?G:GY)
               setTxt('v_dmop',  mem_write?'WRITE':mem_read?'READ':'—',
                                 mem_write?R:mem_read?G:GY)
               setTxt('v_dmaddr',mem_write||mem_read ? 'addr: '+alu_res : 'addr: —', GY)
               setTxt('v_dmval', mem_write ? 'data: '+wr_data : mem_read ? 'data: '+m[0] : '—', GY)

               // Wire labels
               setTxt('lbl_pc_val',  h16(pc),    B)
               setTxt('lbl_alu_res', ''+alu_res, G)
               setTxt('lbl_imm_val', '#'+alu_in2, A)
               setTxt('lbl_wb_val',  'WB='+wr_data, G)
               setTxt('lbl_br_tgt',  '→'+h16(br_tgt), A)

               // Status panel
               setTxt('s_name', name, P)
               setTxt('s_type',
                  '['+tstr+'-format]   reg_write='+( reg_write?1:0)+
                  '   alu_src='+( alu_src?1:0)+'   mem_r='+( mem_read?1:0)+
                  '   mem_w='+( mem_write?1:0)+'   pc_src='+( pc_src?1:0)+
                  (pc_src ? '  ⤴ BRANCH TAKEN → '+h16(br_tgt) : ''), GY)
               setTxt('s_pc',
                  'PC: '+h16(pc)+'   instr: '+h16(instr,8)+
                  '   alu_result: '+alu_res+
                  '   alu_zero: '+( alu_zero?1:0)+
                  '   next_pc: '+( pc_src ? h16(br_tgt) : h16(pc+4)), '#555')

               // Register sidebar
               setTxt('rf_x0', 'X0  (XZR) =  0', '#444')
               for (let i=1;i<6;i++) {
                  let writing = reg_write && rd===i
                  setTxt('rf_x'+i,
                     'X'+i+(i<10?' ':'')+'          =  '+x[i]+(writing?' ← '+wr_data:''),
                     writing?G : x[i]?'#e6edf3':GY)
               }
               setTxt('rf_m0', 'Mem[0]      =  '+(m[0]||0), m[0]?G:GY)
               setTxt('rf_m4', 'Mem[4]      =  '+(m[1]||0), '#555')
               setTxt('rf_m8', 'Mem[8]      =  '+(m[2]||0), '#555')

               //─── Component highlighting ────────────────────────
               ;['pc','pcmux','add4','brad','imem','ctrl','rf','sx','amux','alu','dmem','wmux']
                  .forEach(id => hiComp(id, false, GY))

               hiComp('pc',   true, B)
               hiComp('imem', true, B)
               hiComp('ctrl', true, P)
               hiComp('pcmux', true, pc_src ? A : B)
               hiComp('add4',  !pc_src, B)

               if (!is_b) hiComp('rf',   true, reg_write ? G : B)
               if (is_i||is_d||is_cb||is_b) hiComp('sx', true, A)
               if (is_i||is_d)              hiComp('amux', true, B)
               if (!is_b) hiComp('alu', true, is_r ? G : B)
               if (mem_read || mem_write) hiComp('dmem', true, mem_write ? R : G)
               if (reg_write) hiComp('wmux', true, G)
               if (pc_src || uncond_br || branch_z || branch_nz) hiComp('brad', true, A)

               //─── Wire highlighting ────────────────────────────
               ;['pc_imem','pc_add4','add4_pcmux','br_pcmux','pcmux_pc','imem_ctrl',
                 'imem_rf','imem_sx','sx_amux','rf_alu1','rf_amux','amux_alu',
                 'alu_dmem','stur_data','dmem_wmux','alu_wmux','wmux_rf',
                 'pc_brad','imem_brad'].forEach(id => hiWire(id, null))

               hiWire('pc_imem',   B)
               hiWire('imem_ctrl', P)
               hiWire('pc_add4',   B)

               if (!is_b) { hiWire('imem_rf', P); hiWire('rf_alu1', G) }
               if (!alu_src && !is_b) hiWire('rf_amux', G)
               if (is_i||is_d||is_cb||is_b) hiWire('imem_sx', A)
               if (is_i||is_d) { hiWire('sx_amux', A); hiWire('amux_alu', B) }
               if (!is_b) hiWire('alu_dmem', B)
               if (mem_write)  hiWire('stur_data', R)
               if (mem_read)   hiWire('dmem_wmux', G)
               if (reg_write && !mem_to_reg) hiWire('alu_wmux', B)
               if (reg_write)  hiWire('wmux_rf',   G)

               if (pc_src || uncond_br || branch_z || branch_nz) {
                  hiWire('pc_brad',   A)
                  hiWire('imem_brad', A)
                  hiWire('br_pcmux',  A)
                  hiWire('pcmux_pc',  A)
               } else {
                  hiWire('add4_pcmux', B)
                  hiWire('pcmux_pc',   B)
               }

               // Wire value labels visibility
               ;['lbl_pc_val','lbl_alu_res','lbl_imm_val','lbl_wb_val','lbl_br_tgt']
                  .forEach(id => { let el=document.getElementById(id); if(el) el.setAttribute('fill', el.getAttribute('fill')==='none'?'none':el.getAttribute('fill')) })
               document.getElementById('lbl_pc_val') .setAttribute('fill', B)
               document.getElementById('lbl_alu_res').setAttribute('fill', !is_b ? G : 'none')
               document.getElementById('lbl_imm_val').setAttribute('fill', (is_i||is_d) ? A : 'none')
               document.getElementById('lbl_wb_val') .setAttribute('fill', reg_write ? G : 'none')
               document.getElementById('lbl_br_tgt') .setAttribute('fill', pc_src ? A : 'none')

               //─── Control signal badges ────────────────────────
               badge('b_rw',  reg_write,  G,   'RegWr:'  +(reg_write ?1:0))
               badge('b_as',  alu_src,    B,   'ALUSrc:' +(alu_src   ?1:0))
               badge('b_mr',  mem_read,   B,   'MemRd:'  +(mem_read  ?1:0))
               badge('b_mw',  mem_write,  R,   'MemWr:'  +(mem_write ?1:0))
               badge('b_m2r', mem_to_reg, G,   'Mem2Reg:'+(mem_to_reg?1:0))
               badge('b_pcs', pc_src,     A,   'PCSrc:'  +(pc_src    ?1:0))
               badge('b_ub',  uncond_br,  A,   'UncBr:'  +(uncond_br ?1:0))
               badge('b_bz',  branch_z,   A,   'BrZ:'    +(branch_z  ?1:0))
               badge('b_bnz', branch_nz,  A,   'BrNZ:'   +(branch_nz ?1:0))
               badge('b_r2l', reg2_loc,   P,   'Reg2Loc:'+(reg2_loc  ?1:0))
            }

   // ─────────────────────────────────────────────────────────────
   //  PASS / FAIL
   //  PASS when X5 = 30 (LDUR loads the STUR'd value of X3)
   // ─────────────────────────────────────────────────────────────
   *passed = |cpu/xreg[5]>>1$val == 64'd30;
   *failed = 1'b0;

\SV
   endmodule
