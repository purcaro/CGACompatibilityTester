{$O+,F+}
unit CGACAPTURE;
{Contains all of the video capture test plates}

interface

Procedure BarsRGB;
Procedure BarsRGBI;
Procedure BarsComp;
Procedure MotionTest;
Procedure audioSync;

implementation

uses
  strings,support,m6845ctl,ztimer,cgaccommon,cgastaticdata,
  TInterrupts,{cgalib_g,}cgalib,
  totsys,totmsg,totIO1,totfast,tfastwrite;

var
  framew:word;
  faddr:word;

Procedure MotionTest;
const
  bsize=50;
var
  smsg:string;
  xcol,yrow:word;

begin
  if interactive then begin
    with InfoPrompt do begin
      init(2,strpas(menuLookup[mCapMotion].title));
      WinForm^.vWinPtr^.SetColors(descBorder,descBody,descTitle,descIcons);
      AddLine('');
      AddLine('This test plate consists of two moving lines,');
      AddLine('one horizontal and one vertical, that move at');
      AddLine('the refresh rate of your card and monitor.');
      AddLine('This can be used to observe if your video');
      AddLine('capture setup is dropping or mangling frames.');
      AddLine('');
      SetOption(1,cstring,67,Finished);
      SetOption(2,astring,65,Escaped);
      Result:=Show;
      Done;
    end;
    if Result=Escaped then exit;
  end;
  PrepTest;
  vs:=new(pvidCGAGmode4,Init(mode4,true));
{  asm
    mov ax,0004h
    int 10h
  end;}
  DrawTestplate;
  smsg:='Welcome to medium-res graphics.'#13#10; BIOSWriteStr(smsg);
  if interactive then begin
    smsg:='Press any key to start and end the'#13#10; BIOSWriteStr(smsg);
    smsg:='horizontal and vertical motion test.'#13#10; BIOSWriteStr(smsg);
    PauseUser;
  end;

  xcol:=0;
  yrow:=0;
  framecounter:=0;
  with vs^ do begin
    repeat
      for xcol:=0 to width-2 do begin
        asm
          mov   bl,c_vertical_sync
          MOV   DX,m6845_status
          cli
  @WDR: {wait during retrace, because we don't know where we are in the cycle}
          in    AL,DX
          test  AL,BL {if our bit is 1, then we're already in retrace, which means we missed it}
          jnz   @WDR  {jump if 1 (not 0) = keep looping as long as we're retracing}
  @WDD: {wait for display to be over}
          in    AL,DX
          test  AL,BL
          jz    @WDD  {loop until we aren't drawing any more (ie. retracing)}
        end;
        line(xcol,bsize,xcol,height-bsize,0);
        line(xcol+1,bsize,xcol+1,height-bsize,maxcolors-1);
        asm
          sti
        end;
        if keypressed then break;
      end;

      for yrow:=0 to height-2 do begin
        asm
          mov   bl,c_vertical_sync
          MOV   DX,m6845_status
          cli
  @WDR: {wait during retrace, because we don't know where we are in the cycle}
          in    AL,DX
          test  AL,BL {if our bit is 1, then we're already in retrace, which means we missed it}
          jnz   @WDR  {jump if 1 (not 0) = keep looping as long as we're retracing}
  @WDD: {wait for display to be over}
          in    AL,DX
          test  AL,BL
          jz    @WDD  {loop until we aren't drawing any more (ie. retracing)}
        end;
        line((width div 2)-bsize,yrow,(width div 2)+bsize,yrow,0);
        line((width div 2)-bsize,yrow+1,(width div 2)+bsize,yrow+1,maxcolors-1);
        asm
          sti
        end;
        if keypressed then break;
      end;

    until keypressed or (not interactive);
  end;
  dispose(vs,done);
  PostTest;
end;

Procedure addCaptureText;
begin
  with InfoPrompt do begin
    AddLine('displayed as a traditional color bars test plate');
    AddLine('arranged by *LUMINANCE*.  This can be used to calibrate');
    AddLine('your video capture setup for luminance and range');
    AddLine('using traditional scopes (like a waveform monitor,');
    AddLine('RGB sweep, or luminance histogram).');
  end;
end;

Procedure BarsRGB;
var
  b,barwidth:byte;
begin
  with InfoPrompt do begin
    init(2,strpas(menuLookup[mCapBarsRGB].title));
    WinForm^.vWinPtr^.SetColors(descBorder,descBody,descTitle,descIcons);
    AddLine('');
    AddLine('This pattern consists of all sixteen RGB colors,');
    addCaptureText;
    AddLine('');
    SetOption(1,cstring,67,Finished);
    SetOption(2,astring,65,Escaped);
    Result:=Show;
    Done;
  end;
  if Result=Escaped then exit;
  PrepTest;
  vs:=new(pVidCGAT80x25,Init(text80x25,true));
  with vs^ do begin
    barwidth:=width div 16;
    for b:=0 to 15 do
      box(b*barwidth,0,
          (b*barwidth)+barwidth-1,height-1,
          RecY709sorted[b] or (RecY709sorted[b] shl 4));
  end;
  PauseUser;
  dispose(vs,done);
  PostTest;
end;

Procedure BarsRGBI;
const
  {RGBIcols:array[0..7] of byte=(4,2,1,7,12,10,9,15);}
  RGBIcols:array[0..3] of byte=(4,2,1,15);
var
  b,barwidth:byte;
begin
  if interactive then begin
    with InfoPrompt do begin
      init(2,strpas(menuLookup[mCapRGBI].title));
      WinForm^.vWinPtr^.SetColors(descBorder,descBody,descTitle,descIcons);
      AddLine('');
      AddLine('This pattern consists of RED, GREEN, BLUE, and WHITE bars.');
      AddLine('The red, green, and blue bars use only the red/green/blue pins.');
      AddLine('The white bar uses all four RGBI pins.');
      AddLine('');
      AddLine('This test plate can be used to check or calibrate RGBI converters:');
      AddLine('The red, green, and blue bars should be "pure", with no additional');
      AddLine('coloring.  Also, they should register identical maximum levels');
      AddLine('as compared to each other.');
      AddLine('');
      AddLine('The white bar can be used to calibrate maximum output level.');
      AddLine('The black overscan area can be used to calibrate the minimum level.');
      AddLine('Additionally, any large flat area can be inspected for analog noise.');
      AddLine('');
      SetOption(1,cstring,67,Finished);
      SetOption(2,astring,65,Escaped);
      Result:=Show;
      Done;
    end;
    if Result=Escaped then exit;
  end;
  PrepTest;
  vs:=new(pVidCGAT80x25,Init(text80x25,true));
  with vs^ do begin
    barwidth:=width div 4;
    for b:=0 to 3 do
      box(b*barwidth,0,
          (b*barwidth)+barwidth-1,height-1,
          RGBICols[b] or (RGBICols[b] shl 4));
  end;
  PauseUser;
  dispose(vs,done);
  PostTest;
end;

Procedure BarsComp;
var
  b,barwidth:byte;
begin
  if interactive then begin
    with InfoPrompt do begin
      init(2,strpas(menuLookup[mCapBarsComp].title));
      WinForm^.vWinPtr^.SetColors(descBorder,descBody,descTitle,descIcons);
      AddLine('');
      AddLine('This pattern consists of 16 solid composite colors,');
      addCaptureText;
      AddLine('');
      SetOption(1,cstring,67,Finished);
      SetOption(2,astring,65,Escaped);
      Result:=Show;
      Done;
    end;
    if Result=Escaped then exit;
  end;
  PrepTest;
  vs:=new(pVidCGAGComposite,Init(composite,true));
  with vs^ do begin
    barwidth:=width div 18;
    for b:=0 to 17 do
      box(b*barwidth,0,
          (b*barwidth)+barwidth-1,height-1,
          {b or (b shl 4));}
          CompLumaGroups[b]);
  end;
  PauseUser;
  dispose(vs,done);
  PostTest;
end;


{$F+}
procedure audioSyncHandler; Interrupt;
{
Ok, here's our actual handler. This particular handler just increments
a counter. Then it checks to see if the BIOS handler should be called.
If so, it calls it; if not, it acknowledges the interrupt itself.

Do not do any LONGINT stuff in an interrupt handler with Turbo Pascal 7
because the 32-bit-away routines do not preserve the upper bits of
ax/bx/cx/dx. If you must, and your code will run on 386s or higher,
make sure you PUSH EAX/EBX/ECX/EDX before starting and POP when done.
}

{{$DEFINE EVILINT} {define this if you want your handler to be evil}
begin
  {every so often, switch to new page}
  inc(framecounter);

  framew:=word(framecounter) and 511;
  faddr:=(framew shr 7)*(40*25);
  mem[$b800:(faddr shl 1)+2]:=(framew and 1)+ord('0');
  if (framew and 127)=0 then begin
    case framew of
      128*0,128*1,128*2,128*3:begin
        m6845_SetDisplayAddress(faddr);
        case framew of
            0:Chan2SquarewaveOn(440); {A}
          128:Chan2SquarewaveOn(554); {C#}
          256:Chan2SquarewaveOn(659); {E}
          384:Chan2SquarewaveOn(880);
        end;
      end;
    end;
  end;
  {color the border and sound the bell as long as either shift key
  is held down.  This allows for syncing captured video with
  video footage shot of a keyboard in real time.  Yes, I'm a nerd.}
  if (mem[$40:$17] AND 7)<>0
    then begin
      Chan2SquarewaveOn(880*2);
      asm
        {ensure speaked pinned on -- prev. func. fails sometimes? will check later}
        in      al,61h
        or      al,00000011b
        out     61h,al
        {turn border white}
        mov     dx,m6845_color_sel
        mov     al,0fh
        out     dx,al
      end;
    end else begin
      {turn sound off after 3 visible frames}
      if (framew and 3)=3 then asm
        {unpin speaker}
        in      al,61h
        and     al,11111100b
        out     61h,al
        {turn border black}
        mov     dx,m6845_color_sel
        mov     al,00h
        out     dx,al
      end;
    end;

  {$IFNDEF EVILINT} {We want to be nice, and will maintain the BIOS interrupt}
  inc(PITCycles,Chan0Counter); {Keep track of how many PIT cycles have gone by}
  if longrec(PITCycles).hi <> 0 then begin {Did we roll over?  Is it time to call the 18.2Hz BIOS handler?}
    longrec(PITCycles).hi:=0; {Update our PIT cycles counter}
    asm pushf end; {simulate an interrupt by pushing flags, then CALLing handler}
    BIOSTimerHandler; {this will acknowledge the interrupt}
  end
  else
    Port[$20] := $20; {send EndOfInterrupt to the PIC to ackn. the interrupt}
  {$ELSE}
  Port[$20] := $20; {Just acknowledge the interrupt, oldint8 be damned}
  {$ENDIF}
end;


Procedure audioSync;
const
  maxframetime:longint=60*60*60*2;
type
  pbyte=^byte;
var
  f:file;
  fdata:pointer;
  pmda,pcgathin,pcgathick:pbyte;
  sp:pointer;
  s,it,ss:string;
  br,cr,r:real;
  ibr,icr,l:longint;
  b:byte;
  c:char;

  Procedure DrawCharBox(bx,by:byte;ic:char;fontdata:pbyte);
  var
    x,y,mask:byte;
    s:string[8];
  begin
    inc(word(fontdata),8*byte(ic)); {advance to char in rom font data}
    for y:=0 to 7 do begin
      mask:=$80; s:='';
      for x:=0 to 7 do begin
        if (fontdata^ AND mask)=mask then s:=s+#219 else s:=s+#0;
        mask:=mask SHR 1;
      end;
      tfastwritexy(@s,sp,bx,by+y,$0f);
      inc(word(fontdata));
    end;
  end;

begin
  if interactive then begin
    with InfoPrompt do begin
      init(2,strpas(menuLookup[mSync].title));
      WinForm^.vWinPtr^.SetColors(descBorder,descBody,descTitle,descIcons);
      AddLine('');
      AddLine('This test sequence is designed to detect missing frames');
      AddLine('during video capture, and also detect audio sync drift.');
      AddLine('To use, start your capture process, then begin this test.');
      AddLine('Capture at least 10 minutes, then load the resulting video');
      AddLine('into a video editor that counts frames (such as virtualdub)');
      AddLine('and look for discrepancies between the displayed and captured');
      AddLine('frame numbering.');
      AddLine('');
      br:=60000/1001;
      str(br:2:4,ss);
      it:='NTSC broadcast rate is '+ss+' fields per second,'; AddLine(it);
      cr:=(14318180/12) / 76 / 262;
      str(cr:2:4,ss);
      it:='but the framerate of CGA is '+ss+' frames per second.'; AddLine(it);
      AddLine('If no audio resampling occurs during capture, it is normal to');
      ibr:=round(br*100);
      icr:=round(cr*100);
      l:=lcm(ibr,icr);
      r:=((l / 100) / br) / br;
      r:=round(r);
      str(r:2:0,ss);
      it:='see a discrepancy roughly once every '+ss+' seconds.'; AddLine(it);
      AddLine('');
      AddLine('This test uses pure CGA timings; do not use with compatibles.');
      AddLine('');
      AddLine('For best results, capture between 1-2 hours of video.');
      AddLine('');
      SetOption(1,cstring,67,Finished);
      SetOption(2,astring,65,Escaped);
      Result:=Show;
      Done;
    end;
    if Result=Escaped then exit;
  end else begin
    maxframetime:=timeoutsecs * 60;
  end;
  PrepTest;
  {set up pointers to rom font data}
  getmem(fdata,8192);
  assign(f,datafile);
  reset(f,1);
  blockread(f,fdata^,8192);
  close(f);
  pmda:=fdata; pcgathin:=pmda; pcgathick:=pmda;
  inc(word(pcgathick),6144);
  inc(word(pcgathin),4096);
  sp:=ptr($b800,0);

  tfastinit(40,25*4);
  tfpreventsnow:=false;
  asm
        mov     ax,0001
        int     10h
  end;
  m6845_SetCursorLoc(4*(40*25));

  for b:=0 to 3 do begin
    s:=inttostr(b+1);
    tfastwritexy(@s,sp,39,b*25,$07);
    c:=s[1];
    DrawCharBox(20-4,(b*25)+12-4,c,pcgathick);

    s:='Number intervals NOT aligned to seconds.';
    tfastwritexy(@s,sp,0,(b*25)+22,$07);
    s:='Do not use as a hh:mm:ss time reference!';
    tfastwritexy(@s,sp,0,(b*25)+23,$07);
    s:='Provided for capture sync purposes only.';
    tfastwritexy(@s,sp,0,(b*25)+24,$07);
    s:='( )';
    tfastwritexy(@s,sp,0,b*25,$07);
  end;

  {
  The idea is to have the screen switching and beep sounding on an interrupt.
  That way, background interrupt noise (mouse drivers, packet drivers, etc.)
  can't screw up the timing -- we MUST not skip any interrupts or refreshes,
  or else the test plate is useless for capture sync issue detection.
  }
  framecounter:=-1;
  SetTimerCGAVINT(@audioSyncHandler);
  asm
        hlt     {let interrupt fire at least once}
  end;

  {Write framecounter info to all four pages repeatedly.  Interrupt will take
  care of switching pages, sounding a bell, flashing the border, etc.}
  repeat
    s:=inttostr(framecounter);
    for b:=0 to 3 do tfastwritexy(@s,sp,4,b*25,$07);
  until keypressed or (framecounter>maxframetime);

  CleanUpTimer;
  freemem(fdata,8192);
  PostTest;
end;

end.

