
.SHELL: /bin/bash
.PHONY: all rebuild
.SUFFIXES:
.DEFAULT_GOAL: all


FillValue = 0xFF

ROMVersion = 0
GameID = ISSO
GameTitle = AEVILIA
NewLicensee = 42
OldLicensee = 0x33
# MBC5+RAM+BATTERY
MBCType = 0x1B
# ROMSize = 0x02
SRAMSize = 0x04

bindir = ./bin
objdir = ./obj

CFLAGS = -E -p $(FillValue)
LFLAGS = 
FFLAGS = -Cjv -i $(GameID) -k $(NewLicensee) -l $(OldLicensee) -m $(MBCType) -n $(ROMVersion) -p $(FillValue) -r $(SRAMSize) -t $(GameTitle)

RGBASM = ./rgbasm
RGBLINK = ./rgblink
RGBFIX = ./rgbfix


# Define special dependencies here (see "$(objdir)/%.o" rule for default dependencies
maps_deps	= maps/*.blk
sound_deps	= sound/NoiseData.bin


all: $(bindir)/aevilia.gbc

rebuild: clean all

clean:
	rm $(objdir)/*.o
	rm $(bindir)/aevilia.gbc $(bindir)/aevilia.sym $(bindir)/aevilia.map

$(bindir)/aevilia.sym:
	rm $(bindir)/aevilia.gbc
	make $(bindir)/aevilia.gbc

$(bindir)/aevilia.gbc: $(objdir)/main.o $(objdir)/battle.o $(objdir)/engine.o $(objdir)/home.o $(objdir)/gfx.o $(objdir)/maps.o $(objdir)/save.o $(objdir)/sound.o $(objdir)/tileset.o
	$(RGBLINK) $(LFLAGS) -n $(bindir)/aevilia.sym -m $(bindir)/aevilia.map -o $@ $^
	$(RGBFIX) $(FFLAGS) $@
	
	
$(objdir)/%.o: %.asm constants.asm macros.asm constants/*.asm macros/*.asm %/*.asm $(%_deps)
	$(RGBASM) $(CFLAGS) -o $@ $<

