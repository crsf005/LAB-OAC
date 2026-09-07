
module safecrack_fsm (
    input  logic       clk,      
    input  logic       rst_n,    
    input  logic [3:0] btn,      
    output logic       unlocked  
);


typedef enum logic [4:0] {
    S_INIT     = 5'b00001, 
    S_AZUL     = 5'b00010, 
    S_AMARELO1 = 5'b00100,
    S_AMARELO2 = 5'b01000, 
    S_UNLOCKED = 5'b10000  
} state_t;

state_t state, next_state;

logic [3:0] btn_prev; 
logic       btn_event; 


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_prev <= 4'b0000;
    else        btn_prev <= btn;
end


assign btn_event = (btn != 4'b0000) && (btn_prev == 4'b0000);


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_INIT;
    else        state <= next_state;
end

always_comb begin
    next_state = state;  

    if (btn_event) begin
        unique case (state)
            S_INIT:     if (btn == 4'b0001) next_state = S_AZUL;     
                        else                next_state = S_INIT;     
                        
            S_AZUL:     if (btn == 4'b0010) next_state = S_AMARELO1; 
                        else                next_state = S_INIT;     
                        
            S_AMARELO1: if (btn == 4'b0010) next_state = S_AMARELO2; 
                        else                next_state = S_INIT;     
                        
            S_AMARELO2: if (btn == 4'b1000) next_state = S_UNLOCKED; 
                        else                next_state = S_INIT;     
                        
            S_UNLOCKED: next_state = S_UNLOCKED; 
            
            default:    next_state = S_INIT;
        endcase
    end
end

assign unlocked = (state == S_UNLOCKED);

endmodule