`timescale 1ns / 1ps

	module process (
        input                clk,		    	// clock 
        input  [23:0]        in_pix,	        // valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
        input  [8*512-1:0]   hiding_string,     // sirul care trebuie codat
        output reg[6-1:0]    row, col, 	        // selecteaza un rand si o coloana din imagine
        output reg           out_we, 		    // activeaza scrierea pentru imaginea de iesire (write enable)
        output reg [23:0]    out_pix,	        // valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
        output reg           gray_done,		    // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
        output reg           compress_done,		// semnaleaza terminarea actiunii de compresie (activ pe 1)
        output reg           encode_done        // semnaleaza terminarea actiunii de codare (activ pe 1)
    );	
    
    //TODO - instantiate base2_to_base3 here
	 wire [31:0] base3_no;
	 wire done;
	 reg [15:0] base2_no;
	 reg en = 0;
	 base2_to_base3 base(base3_no, done, base2_no, en, clk);
    
    //TODO - build your FSM here
	 
	 reg [5:0] state=0;
	 reg [5:0] next_state;
	 reg [7:0] min, max;
	 integer avg = 0, var = 0;
	 integer i, j, ii, jj;
	 integer m = 4;        //dimensiunea sub-blocurilor
	 integer r = 0, c = 0; //indici folositi pentru parcurgerea imaginii in blocuri de 4x4
	 integer nr_1 = 0;     //numarul bitilor de 1 din harta
	 integer L, H;
	 integer index_string; //folosit pentru a citi pe rand cate 16 biti din hiding_string
	 integer b3_n;         //memoreaza numarul in baza 3
	 integer check;        //numarul de pixeli omisi pentru decodarea mesajului
	 integer check_val;    //valoarea primului pixel omis pentru decodarea mesajului
	 integer index;        //folosit pentru a selecta pe rand cate 2 biti din numarul in baza 3
	 integer aux;          //valoarea primului pixel din bloc
	 integer ok;           //verifica daca exista pixeli cu valori diferite in bloc
	 
	 
	 
	 always @(posedge clk) begin
		state <= next_state;
	 end
	 
	 always @(*) begin
		gray_done = 0;           //initializarile facute pentru fiecare ciclu de ceas
		compress_done = 0;
		encode_done = 0;
		en = 0;
		out_we = 0;
		
		case (state)
			0: begin
				i = 0;
				j = 0;
				next_state = 1;
			end
			
			1: begin                        //calculeaza minimul dintre valorile din canelele 'R', 'G' si 'B'
				row = i;
				col = j;
				min = in_pix[23:16];
				if (in_pix[15:8] < min)
					min = in_pix[15:8];
				if (in_pix[7:0] < min)
					min = in_pix[7:0];
				next_state = 2;
			end

			2: begin                       //calculeaza maximul dintre valorile din canelele 'R', 'G' si 'B' 
				max = in_pix[23:16];
				if (in_pix[15:8] > max)
					max = in_pix[15:8];
				if (in_pix[7:0] > max)
					max = in_pix[7:0]; 
				next_state = 3;
			end
			
			3: begin                       
				out_pix[15:8] = (min+max)/2;  //calculeaza media dintre minim si maxim si o stocheaza pe canalul 'G'
				out_pix[23:16] = 0;           //canalele 'R' si 'B' sunt setate pe valoarea zero
				out_pix[7:0]= 0;
				out_we = 1;
				                                    //incrementeaza linia si coloana pentru parcurgerea imaginii
				if(col == 63 && row == 63) begin    //conditie finalizare bloc
					next_state = 4;
				end else if(col == 63) begin        //conditie finalizare rand
					j = 0;
					i = i + 1;
					next_state = 1;
				end else begin
					j = j + 1;
					next_state = 1;
				end
				
			end
				
			4: begin                
				gray_done = 1;   //indicatorul devine 1 semnaland finalizarea conversiei
				next_state = 5;
			end
			
			5: begin            //incepe etapa de compresie a imaginii
				avg = 0;
				i = 0;
				j = 0;
				next_state = 6;
			end
			
			6: begin
				if(state == next_state) begin  //imaginea este parcursa in blocuri de 4x4
					row = i + r;		          //i si j se ocupa de parcurgerea fiecarui bloc in parte luand valori de la 0 la 3
					col = j + c;                //r si c memoreaza indicii primului pixel din fiecare bloc
					next_state = 7;
				end
			end
			
			7: begin
				avg = avg + in_pix[15:8];      //calculeaza suma elementelor din fiecare bloc in parte
				next_state = 8;
			end
			
			8: begin
				if(state == next_state) begin
					if(j == 3 && i == 3) begin
						next_state = 9;
					end else if(j == 3) begin
						j = 0;
						i = i + 1;
						next_state = 6;
					end else begin
						j = j + 1;
						next_state = 6;
					end
				end
			end
			
			9: begin
				if(state == next_state) begin       
					avg = avg / (m * m);         //calculeaza media elementelor din fiecare bloc in parte
					i = 0;                       //repozitioneaza indicii la inceputul blocului
					j = 0;
					var = 0;
					next_state = 10;
				end
			end
			
			10: begin
				if(state == next_state) begin
					row = i + r;
					col = j + c;
					next_state = 11;
				end
			end
			
			11: begin
				if(state == next_state) begin    //calculeaza suma diferentelor dintre fiecare pixel si AVG in modul
					if(in_pix[15:8] > avg) begin
						var = var + in_pix[15:8] - avg;
					end else begin
						var = var + avg - in_pix[15:8];
					end
					next_state = 12;
				end
			end
			
			12: begin
				if(state == next_state) begin
					if(j == 3 && i == 3) begin
						next_state = 13;
					end else if(j == 3) begin
						j = 0;
						i = i + 1;
						next_state = 10;
					end else begin
						j = j + 1;
						next_state = 10;
					end
				end
			end
			
			13: begin
				var = var / 16;     //calculeaza var
				i = 0;              //repozitioneaza indicii la inceputul blocului
				j = 0;
				nr_1 = 0;           //numarul bitilor de 1 din harta
				next_state = 14;
			end
			
			14: begin
				if(state == next_state) begin
					row = i + r;
					col = j + c;
					next_state = 15;
				end
			end
			
			15: begin                             //construieste harta cu valorile 1 si 0
				if(state == next_state) begin   
					if(in_pix[15:8] < avg) begin
						out_pix[15:8] = 0;
					end else begin
						out_pix[15:8] = 1;
						nr_1 = nr_1 + 1;            //incrementeaza cand gaseste un 1
					end
					out_we = 1;
					next_state = 16;
				end
			end
			
			16: begin
				if(state == next_state) begin
					if(j == 3 && i == 3) begin
						next_state = 17;
					end else if(j == 3) begin
						j = 0;
						i = i + 1;
						next_state = 14;
					end else begin
						j = j + 1;
						next_state = 14;
					end
				end
			end
			
			17: begin                 //calculeaza valorile L si H
				L = avg - (m * m * var) / (2 * (m * m - nr_1));
				H = avg + (m * m * var) / (2 * nr_1); 
				i = 0;                 //repozitioneaza indicii la inceputul blocului
				j = 0;
				next_state = 18;
			end
			
			18: begin
				if(state == next_state) begin
					row = i + r;
					col = j + c;
					next_state = 19;
				end
			end
			
			19: begin                              //reconstruieste blocul 
				if(state == next_state) begin
					if(in_pix[15:8] == 0) begin
						out_pix[15:8] = L;            //pune valoarea L pe pozitiile marcate cu 0
					end else begin
						out_pix[15:8] = H;            //pune valoarea H pe pozitiile marcate cu 1
					end
					out_we = 1;
					next_state = 20;
				end
			end
			
			20: begin
				if(state == next_state) begin
					if(j == 3 && i == 3) begin
						next_state = 21;
					end else if(j == 3) begin
						j = 0;
						i = i + 1;
						next_state = 18;
					end else begin
						j = j + 1;
						next_state = 18;
					end
				end
			end
				
			21: begin               //se face trecerea la blocul urmator
				if(col == 63 && row == 63) begin
					next_state = 22;
				end else if(col == 63) begin
					c = 0;
					r = r + 4;
					next_state = 5;
				end else begin
					c = c + 4;
					next_state = 5;
				end
			end
			
			22: begin
				compress_done = 1;   //indicatorul devine 1 semnaland finalizarea compresiei
				r = 0;
				c = 0;
				index_string = 0;    
				next_state = 23;
			end
			
			23: begin
				en = 1;                                        //activeaza semnalul en
				base2_no =  hiding_string[index_string+:16];   //selecteaza cate 16 biti din hiding_string incepand cu bitul 0
				i = 0;
				j = 0;
				index = 0;
				check = 0;
				next_state = 24;
			end
			
			24: begin
				if(done == 1) begin   //verifica daca s-a terminat conversia din baza 2 in baza 3
					b3_n = base3_no;   //memoram valoarea in baza 3 rezultata 
					row = 0;
					col = 0;
					next_state = 28;   //verificare pentru situatia in care L si H sunt egale
				end
				else begin
					next_state = 24;
				end
			end
		
			25: begin
				if(state == next_state) begin
					row = i + r;
					col = j + c;
					next_state = 26;
				end
			end
			
			26: begin
				if(state == next_state) begin
					if(check == 0) begin       //cazul in care inca nu am omis niciun pixel 
						check_val = in_pix[15:8];
						check = 1;
						next_state = 25;
					end else if(check == 1 && in_pix[15:8] != check_val) begin //cazul in care am omis un pixel si am gasit altul cu o valoare diferita de primul
						check = 2;
						next_state = 25;
					end else begin  //cazul in care am omis deja cei 2 pixeli folositi pentru decodarea mesajului
						if(b3_n[index+:2] == 1) begin
							out_pix[15:8] = in_pix[15:8] + 1;
							out_we = 1;
						end else if(b3_n[index+:2] == 2 )begin
							out_pix[15:8] = in_pix[15:8] - 1;
							out_we = 1;
						end
						index = index + 2; //folosit pentru a selecta pe rand cate 2 biti din numarul in baza 3
					end
					next_state = 27;
				end
			end
			
			27: begin
				if(state == next_state) begin           //incrementeaza linia si coloana pentru parcurgerea blocului
					if(j == 3 && i == 3) begin    
						if(col == 63 && row == 63) begin  //trece la blocul urmator
							next_state = 32;
						end else if(col == 63) begin
							c = 0;
							r = r + 4;
							index_string = index_string + 16;  //incrementeaza indicele pentru selectarea caracterelor din string
							next_state = 23;
						end else begin
							c = c + 4;
							index_string = index_string + 16;  //incrementeaza indicele pentru selectarea caracterelor din string
							next_state = 23;
						end
					end else if(j == 3) begin
						j = 0;
						i = i + 1;
						next_state = 25;
					end else begin
						j = j + 1;
						next_state = 25;
					end
				end
			end
			
			28: begin    //verificare pentru situatia in care L si H sunt egale
				ii = 0;
				jj = 0;
				ok = 0;
				row = ii + r;
				col = jj + c;
				next_state = 33;
			end
			
			33: begin
				if(state == next_state) begin
					aux = in_pix[15:8]; //memoreaza valoarea primului pixel din bloc
					next_state = 29;
				end
			end
			
			29: begin
				row = ii + r;
				col = jj + c;
				next_state = 30;
			end
			
			30: begin
				if(in_pix[15:8] != aux) begin  //daca gasim un pixel cu valoare diferita de primul revenim la pasul 25
					ok = 1;
					next_state = 25;
				end else begin
					next_state = 31;
				end
			end
			
			31: begin 
				if(state == next_state) begin  //parcurgem blocul
					if(jj == 3 && ii == 3) begin
						if(ok == 0) begin   //daca ajungem la finalul blocului si nu am gasit nicio valoare diferita de prima
							check = 2;       //vom omite primii 2 pixeli deci check devine 2
							j = 2;           //si actualizam indicele pentru coloana trecand direct la al treilea pixel
							next_state = 25;
						end
					end else if(jj == 3) begin
						jj = 0;
						ii = ii + 1;
						next_state = 29;
					end else begin
						jj = jj + 1;
						next_state = 29;
					end
				end
			end
				
				
			32: begin 
				encode_done = 1;  //indicatorul devine 1 semnaland finalizarea incapsularii mesajului
			end
				
			
		endcase
	 end
    
endmodule
