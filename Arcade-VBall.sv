//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + per-pin push-pull mask, USER_IO widened to 8 bits
	output        USER_OSD,
	output  [7:0] USER_PP,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driven by wrapper; USER_OUT driven by joydb (USER_OUT_DRIVE) below
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
// assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 1;
// assign AUDIO_L = 0;
// assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_USER = 0;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////
// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
//    XXX  XXXXXXXXXX

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd320 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd313 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
	"VBall;;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
 	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"-;",
	"P1,Video Settings;",
	"P1OAD,H Center,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"P1OEG,V Center,0,+1,+2,+3,-4,-3,-2,-1;",
	"P1OH,YC Video Timing,Off,On;",
	"-;",
	"DIP;",
	"-;",
	// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	"O[125],UserIO Players, 1 Player,2 Players;",
	// [MiSTer-DB9-Pro END]
	"T7,Service;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"J1,Start1P,Start2P,A,B,CoinA,CoinB,Service;",
	"V,v",`BUILD_DATE
};

wire [21:0] gamma_bus;
wire forced_scandoubler;
wire  [1:0] buttons;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: widen status to 128 bits for joy_type at [127:126]
wire [127:0] status;
// [MiSTer-DB9 END]
wire [10:0] ps2_key;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait=0;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: rename USB joystick wires (P1/P2 come from joydb when enabled)
wire [15:0] joystick_0_USB;
wire [15:0] joystick_1_USB;
// [MiSTer-DB9 END]
wire [15:0] joystick_2;
wire [15:0] joystick_3;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression. Default 1'b0 (no MT32 on this core).
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;

// [MiSTer-DB9 BEGIN] - DB9 programmable-remap matrix wires
// joydb_*_mapped = MiSTer-standard joystick words (consumed in Layer B);
// db9_remap_* = 0xFD selector stream driven by the hps_io instance.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open; remap joydb bits to VBall order
// VBall consumer order (CONF_STR "J1,Start1P,Start2P,A,B,CoinA,CoinB,Service"):
//   dirs [3:0]=R/L/D/U  [4]=Start1P  [5]=Start2P  [6]=A  [7]=B  [8]=CoinA  [9]=CoinB
//   (COIN1=~joystick_0[8], COIN2=~joystick_0[9]; Start1P=joystick_0[4],
//    Start2P=joystick_1[4]; Service=status[7], keyboard-only.)
// joydb_1 source bits: [3:0]=R/L/D/U [4]=A [5]=B [6]=C [9]=Z [10]=Start [11]=Mode/R-trigger
// VBall is a 2-game-button core (A,B) -> Rule 1 applies (3-button-MD playable):
//   CoinA <- joydb_1[11] | (joydb_1[10] & joydb_1[5])  (Mode/Select OR Start+B chord)
//   CoinB <- joydb_1[9] (Z, convenience secondary coin slot)
//   A     <- joydb_1[4]   B <- joydb_1[5]   Start1P <- joydb_1[10]
//   Start2P slot ([5]) left 0 on P1 (VBall reads P2 start from joydb_2[10]).
wire [15:0] joystick_0 = joydb_1ena ? (OSD_STATUS ? 16'b0 :
       {6'b0, joydb_1[9], joydb_1[11] | (joydb_1[10] & joydb_1[5]),
        joydb_1[5], joydb_1[4], 1'b0, joydb_1[10], joydb_1[3:0]})
     : joystick_0_USB;
wire [15:0] joystick_1 = joydb_2ena ? (OSD_STATUS ? 16'b0 :
       {8'b0, joydb_2[5], joydb_2[4], 1'b0, joydb_2[10], joydb_2[3:0]})
     : joydb_1ena ? joystick_0_USB : joystick_1_USB;
// [MiSTer-DB9-Pro END]

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),
    .new_vmode(new_vmode),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
	.joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
	// programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
	.db9_remap_cmd(db9_remap_cmd),
	.db9_remap_byte_cnt(db9_remap_byte_cnt),
	.db9_remap_din(db9_remap_din),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
	.saturn_unlocked(saturn_unlocked)
	// [MiSTer-DB9-Pro END]

);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, locked, clk_vid, clk_48;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 96
	.outclk_1(clk_48),
  	.outclk_2(clk_vid), // 6
	.locked(locked)
);

assign DDRAM_CLK = clk_48;

wire cen_main, cen_pcm,cen_vid;
clk_en #(18) clk_en_6502(clk_sys, cen_main);
//clk_en #(4) clk_en_snd(clk_snd, cen_snd);
clk_en #(91) clk_en_pcm(clk_48, cen_pcm);
clk_en #(3) clk_en_vid(clk_48, cen_vid);

reg clk_snd;
reg [2:0] cnt;
always @(posedge clk_sys) begin
  cnt <= cnt + 3'd1;
  if (cnt == 3'd3) begin
    cnt <= 3'd0;
		clk_snd <= ~clk_snd;
  end
end

//Generate 3.579545MHz clock enable for 
//(uses Jotego's fractional clock divider from JTFRAME)
wire [9:0] sound_cen_n = 10'd44;
wire [9:0] sound_cen_m = 10'd295;
wire cen_snd;
jtframe_frac_cen #(2) sound_cen
(
	.clk(clk_snd),
	.n(sound_cen_n),
	.m(sound_cen_m),
	.cen({1'bZ,cen_snd})
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

//////////////////////////////////////////////////////////////////

reg [7:0] sw[8];
always @(posedge clk_sys)
	if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

wire SERVICE = ~status[7];
wire [7:0] P1 = ~{
	joystick_0[4], // start1p
	joystick_0[5], // start1p
	joystick_0[7], // B
	joystick_0[6],	// A
	joystick_0[2], // down
	joystick_0[3], // up
	joystick_0[1], // left
	joystick_0[0], // right
};

wire [7:0] P2 = ~{
	joystick_1[4], // start2p
	joystick_1[5], // start1p
	joystick_1[7], // B
	joystick_1[6],	// A
	joystick_1[2], // down
	joystick_1[3], // up
	joystick_1[1], // left
	joystick_1[0], // right
};

wire [7:0] P3 = ~{
	joystick_2[4],// start3p
	joystick_2[5], // B
	joystick_2[7], // B
	joystick_2[6],	// A
	joystick_2[2], // down
	joystick_2[3], // up
	joystick_2[1], // left
	joystick_2[0], // right
};

wire [7:0] P4 = ~{
	joystick_0[4],// start4p
	joystick_3[5], // B
	joystick_3[7], // B
	joystick_3[6],	// A
	joystick_3[2], // down
	joystick_3[3], // up
	joystick_3[1], // left
	joystick_3[0], // right
};

wire COIN1 = ~joystick_0[8]; // R2?
wire COIN2 = ~joystick_0[9]; // ?

vball vball
(
	.reset(reset),
	.clk_sys(clk_sys),
	.clk_en(cen_main),
	.clk_snd(clk_snd),
	.cen_snd(cen_snd),
  	.cen_pcm(cen_pcm),
  	.clk_vid(clk_vid),

	.idata(ioctl_dout),
	.iaddr(ioctl_addr),
	.iload(ioctl_wr && ioctl_download && (ioctl_index==0)),

	.red(red),
	.green(green),
	.blue(blue),

	.hs(HSync),
	.vs(VSync),
	.hb(HBlank),
	.vb(VBlank),

	.h_center(status[13:10]),    //Screen centering
	.v_center(status[16:14]),
	.ycmode(status[17]),

	.bg_addr(bg_addr),
	.bg_data(bg_data),
	.bg_read(bg_read),

	.pcm_rom_addr(pcm_rom_addr),
	.pcm_rom_data(pcm_rom_data),
	.pcm_rom_read(pcm_rom_read),
	.pcm_rom_data_rdy(pcm_rom_data_rdy),

	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R),

	.P1(P1),
	.P2(P2),
	.P3(P3),
	.P4(P4),

	.COIN1(COIN1),
	.COIN2(COIN2),
	.SERVICE(SERVICE),

	.DSW1(sw[0]),
	.DSW2(sw[1])

);

reg ce_pix;
always @(posedge clk_48)
  if (cen_vid)  // 12
    ce_pix <= ~ce_pix;

arcade_video #(240,12) arcade_video
(
  .*,
  .clk_video(clk_48),
  .RGB_in({ red, green, blue }),
  .fx(status[5:3])
);

// If video timing changes, force mode update
reg [1:0] video_status;
reg new_vmode = 0;
always @(posedge clk_48) begin
    if (video_status != status[17]) begin
        video_status <= status[17];
        new_vmode <= ~new_vmode;
    end
end

wire HBlank, VBlank;
wire HSync, VSync;
wire [3:0] red, green, blue;

wire [18:0] bg_addr;
wire [7:0] bg_data;
wire bg_read;

sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.addr(ioctl_download ? ioctl_addr : bg_addr),
	.wtbt(0),
	.dout(bg_data),
	.din(ioctl_dout),
	.rd(bg_read),
	.we(ioctl_index == 0 && ioctl_wr),
	.ready()
);

wire [63:0] ddram_data;
wire [17:0] pcm_rom_addr;
wire [7:0] pcm_rom_data = ddram_data[(pcm_rom_addr[2:0]*8)+:8];
wire pcm_rom_read;
wire pcm_rom_data_rdy;

ddram ddram
(
	.*,

	.ch1_addr(pcm_rom_addr),
	.ch1_dout(ddram_data),
	.ch1_din(64'b0),
	.ch1_rnw(1'b1),
	.ch1_req(pcm_rom_read),
	.ch1_ready(pcm_rom_data_rdy)
);

endmodule
