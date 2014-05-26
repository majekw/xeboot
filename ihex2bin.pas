// (C) 2007 Marek Wodzinski
// zamienia intel hex na binary
// dodatkowo koduje poprzez mieszanie bajtów w obrêbie jednego sektora (128B) i xoruje
//
// Changelog:
// 2007.11.18	- all done

const
    mieszacz:byte=79;

var
    pamiec,crypted:array[0..65535] of byte;
    linia:array[0..255] of byte;
    s:string;
    baseadr,maxadr,curadr:longint;
    suma,i,j,dlugosc:integer;
    poczatek,a,b:byte;
    
    
function str2hex(hex:string):longint;
var
    wynik:longint;
    maly:integer;
begin
    wynik:=0;
    while hex<>'' do
    begin
	wynik:=wynik*16;
	maly:=ord(hex[1])-48;
	if maly>10 then maly:=maly-7;
	wynik:=wynik+maly;
	delete(hex,1,1);
    end;
    str2hex:=wynik;
end;


begin
    //maksymalny adres znaleziony w pliku
    maxadr:=0;
    //adres bazowy
    baseadr:=0;
    
    //parsowanie pliku
    while not eof(input) do
    begin
	readln(input,s);
	
	//sprawdzenie formatu
	if s[1]<>':' then
	begin
	    writeln(stderr,'No Intel HEX format!');
	    halt;
	end;
	
	//skasowanie :
	delete(s,1,1);
	
	//wczytanie do tablicy
	dlugosc:=length(s) div 2;
	suma:=0;
	for i:=0 to dlugosc-1 do
	begin
	    linia[i]:=str2hex(s[i*2+1]+s[i*2+2]);
	end;
	
	//suma kontrolna
	suma:=0;
	for i:=0 to dlugosc-2 do
	begin
	  suma:=(suma+linia[i]) mod 256;
	end;
	write(stderr,s,' ',suma);
	if ((suma+linia[dlugosc-1]) mod 256)=0 then write(stderr,' OK') else
	begin
	    writeln(stderr,'Bad checksum!!');
	    halt;
	end;
	writeln(stderr);
	
	//adres
	curadr:=baseadr+linia[1]*256+linia[2];
	
	//typ rekordu
	if linia[3]=2 then
	begin
	    //adres bazowy
	    baseadr:=(linia[4]*256+linia[5])*16;
	end else
	if linia[3]=1 then
	begin
	    //eof
	end else
	if linia[3]=0 then
	begin
	    //data record
	    for i:=1 to linia[0] do
	    begin
		pamiec[curadr]:=linia[3+i];
		curadr:=curadr+1;
	    end;
	    if maxadr<curadr then maxadr:=curadr;
	end;
    end;
    writeln(stderr,'max addr: ',maxadr);
    
    
    //zakoduj
    //podbicie maxadr do wielokrotnosci 128
    if (maxadr mod 128)<>0 then maxadr:=128*((maxadr div 128)+1);
    
    //kodujemy po 128B
    for i:=0 to (maxadr div 128)-1 do
    begin
	poczatek:=$39;
	curadr:=0;
	for j:=0 to 127 do
	begin
	    curadr:=(curadr+mieszacz) mod 128;
	    poczatek:=poczatek xor pamiec[i*128+j];
	    //poczatek:=pamiec[i*128+j];
	    crypted[i*128+curadr]:=poczatek;
	    //poczatek:=pamiec[i*128+j];
	    
	    a:=poczatek div 16;	//swap nibbles
	    b:=poczatek mod 16;
	    poczatek:=b*16+a;
	end;
    end;
    
    
    //zapis pliku
    for i:=0 to maxadr-1 do
    begin
	//write(chr(pamiec[i]));
	write(chr(crypted[i]));
    end;
    
end.
