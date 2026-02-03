module cfu_input_buffer #(
    parameter integer DEPTH  = 256,
    parameter integer ADDR_W = 8
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        clear,

    // write side
    input  wire        write_en,
    input  wire [31:0] write_data,
    output wire        write_full,

    // read side: prefetch design (data always valid when not empty)
    input  wire        read_en,
    output reg  [31:0] read_data,
    output wire        read_data_valid,
    output wire        read_empty,

    output wire [8:0]  count
);

    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    reg [ADDR_W-1:0] rd_ptr;
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W:0]   cnt;

    assign write_full = (cnt == DEPTH);
    assign read_empty = (cnt == 0);
    assign count      = cnt;
    
    // Data is valid whenever buffer is not empty (prefetch design)
    assign read_data_valid = !read_empty;

    wire do_write;
    wire do_read;

    assign do_write = write_en && !write_full;
    assign do_read  = read_en  && !read_empty;

    // Next read pointer for prefetch
    wire [ADDR_W-1:0] next_rd_ptr;
    assign next_rd_ptr = rd_ptr + 1'b1;

    always @(posedge clk) begin
        if (rst || clear) begin
            rd_ptr <= {ADDR_W{1'b0}};
            wr_ptr <= {ADDR_W{1'b0}};
            cnt    <= {(ADDR_W+1){1'b0}};
            read_data <= 32'b0;
        end else begin
            // WRITE
            if (do_write) begin
                mem[wr_ptr] <= write_data;
                wr_ptr <= wr_ptr + 1'b1;
            end

            // READ: advance pointer when reading
            if (do_read) begin
                rd_ptr <= next_rd_ptr;
            end

            // Always update read_data from current rd_ptr (prefetch)
            read_data <= mem[rd_ptr];

            // COUNT update (single point)
            case ({do_write, do_read})
                2'b10: cnt <= cnt + 1'b1;
                2'b01: cnt <= cnt - 1'b1;
                default: cnt <= cnt;
            endcase
        end
    end

endmodule
