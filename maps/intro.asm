
SECTION "Intro map", ROMX
IntroMap::
	db $80
	
	db MUSIC_NONE ; No music
	
	db TILESET_INTRO
	dw IntroMapScript
	map_size 15, 18
	dw NO_SCRIPT
	
IntroMapInteractions::
	db 0
	
IntroMapNPCs::
	db 6
	
	interact_box $0128, $0070, 16, 16 ; X hitbox
	db 0 ; Interaction ID
	db 1 << 2 + DIR_DOWN ; Sprite ID & direction
	dn 1, 1, 1, 1 ; Palette IDs
	db 0 ; Movement permissions
	db 0 ; Movement speed
	
	; Dummy NPC for the camera to focus on during gender selection
	interact_box $00D0, $0000, 0, 0
	db 0
	db 2 << 2 | DIR_DOWN
	dn 0, 0, 0, 0
	db 0
	db 0
	
	; Dummy NPCs to display some of the character's eye colors to override some palette limitations
	interact_box $00C8, $0018, 0, 0
	db 0
	db 3 << 2 | DIR_LEFT
	dn 1, 1, 1, 1
	db 0
	db 0
	
	interact_box $00C8, $0020, 0, 0
	db 0
	db 4 << 2 | DIR_LEFT
	dn 1, 1, 1, 1
	db 0
	db 0
	
	interact_box $00C8, $0070, 0, 0
	db 0
	db 4 << 2 | DIR_RIGHT
	dn 1, 1, 1, 1
	db 0
	db 0
	
	interact_box $00C8, $0078, 0, 0
	db 0
	db 3 << 2 | DIR_RIGHT
	dn 1, 1, 1, 1
	db 0
	db 0
	
	db 1
	dw IntroMapNPCScripts
	
	db 4
	dw TestNPCTiles
	dw InvisibleTiles
	dw (LeftEyeTiles - 16 * 4 * 2) ; Make it so the actual tiles land in the slot for left/right, but without using padding
	dw (RightEyeTiles - 16 * 4 * 2)
	
IntroMapWarpToPoints::
	db 2
	
	dw $0028
	dw $0010
	db DIR_RIGHT
	db NO_WALKING
	db 2
	dw CharSelectLoadingScript
	ds 7
	
TUTORIAL_STARTING_YPOS = $0028
TUTORIAL_STARTING_XPOS = $0010
	
	dw TUTORIAL_STARTING_YPOS
	dw TUTORIAL_STARTING_XPOS
	db DIR_RIGHT
	db NO_WALKING
	db 0
	dw IntroMapLoadingScript
	ds 7
	
IntroMapBlocks::
INCBIN "maps/intro.blk"
	
	
InvisibleTiles::
	dwfill 2 * 3 * 4 * 8, $0000 ; (1 "still" set + 1 "moving" set) * 3 directions * 4 tiles * 8 lines


; The NPCs that use these can't be interacted with, so only one side will be coded (two because it's both left and right, left for Evie and mirrored left = right for Tom)
LeftEyeTiles::
	dw $F0F0, $F0F0, $68F8, $E8F8, $F0F0, $F0F0, $0000, $8080
	dw $9090, $6060, $0000, $0101, $0101, $0101, $0202, $0202
	dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
	dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
RightEyeTiles::
	dw $0000, $0101, $0101, $0001, $0001, $0001, $0001, $0000
	dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
	dw $83FF, $1FFF, $3CFF, $3CFF, $3FFF, $3FFF, $01C1, $20E0
	dw $10F0, $0F3F, $0000, $0000, $0000, $0000, $0000, $0000
	
	
IntroMapNPCScripts::
	dw IntroNPC0Script
	
IntroNPC0Script::
	print_name .name
	print_line .line0
	print_line .line1
	delay 100
	text_bankswitch BANK(wIntroMapStatus)
	text_lda wIntroMapStatus
	text_inc
	text_sta wIntroMapStatus
	text_bankswitch 1
	clear_box
	print_line .line2
	close_quick
	done
	
.name
	dstr "FRIENDLY NPC"
	
.line0
	dstr "Hi! It's rare to"
.line1
	dstr "see someone here!"
.line2
	dstr "My name is Jo"
	
	
; The caracter selection screen is actually part of the intro map (who would've known)
; The first loading script basically resets the tutorial
CharSelectLoadingScript::
	ld a, BANK(wIntroMapStatus)
	call SwitchRAMBanks
	xor a ; Initialize the map's status
	ld [wIntroMapStatus], a
	ld [wIntroMapDelayStep], a
	ldh [hOverworldButtonFilter], a
	inc a
	call SwitchRAMBanks
	jp PreventJoypadMovement ; Prevent player's movement, joypad input will only be used for the charselect, not to move the player
	
; Second loading script ; using a warp is more practical (notably because it provides an automated fade with some code exec in the middle)
; Also because it helps setting the map to a known state before the player is allowed to see the player even once
IntroMapLoadingScript::
	xor a ; Close the textbox that was left open by the previous script
	ld [wTextboxStatus], a
	jp AllowJoypadMovement ; Cancel above prevention
	
; The map script is basically a dispatcher, which either calls a function or processes some text depending on wIntroMapStatus
IntroMapScript::
	ld a, BANK(wIntroMapStatus)
	call SwitchRAMBanks
	ld a, [wIntroMapStatus] ; Read the index
	ld b, a ; Save for both dispatching and advancing status
	
	; Calculate status script pointer
	and %1111 ; Only bits 0-3 are used for status
	add a, a ; This is pretty standard, 2 bytes per pointer
	add a, IntroScripts & $FF
	ld l, a
	ld h, IntroScripts >> 8 ; hl points to the next pointer (the purpose / usage of which differs based on index parity)
	; Note : this assumes there's no carry. May not be true, if then move the pointer array around
	
	; Depending on status parity, the pointer should be interpreted differently
	bit 0, b ; If it's an even status, it's a text pointer
	jr nz, .runSpecificScript ; If it's an odd status, it's a code pointer
	
	inc b ; The text should only pop once
	ld a, b
	ld [wIntroMapStatus], a ; So we increment the status!
	
	; Now, we process the text
	ld c, BANK(IntroTexts)
	ld a, [hli]
	ld d, [hl]
	ld e, a
	jpacross ProcessText_Hook
	
.runSpecificScript
	ld a, [hli]
	ld h, [hl]
	ld l, a
	or h ; Check if that's not a NULL
	jr nz, @+1 ; No script, don't run it
	
	ld a, 1
	jp SwitchRAMBanks
	
; MAKE SURE THIS DOES NOT CROSS A 256-BYTE BOUNDARY!!
; (Except for the last byte, which is allowed to)
	db 0
IntroScripts::
	dw IntroBoyGirlText
	dw IntroChooseGender
	dw IntroChoseGenderText
	dw IntroFadeToNarrator
	dw IntroGreetText
	dw IntroResetDelayStep
	dw IntroPressAText
	dw IntroWaitNextState
	dw IntroObjectNeededText
	dw 0 ; Don't do anything, the NPC script advances the status by itself
	dw IntroRemovedNPCText
	dw IntroCheckStartMenu
	
	
;SECTION "Intro map scripts", ROMX,ALIGN[5]
	
IntroChooseGender::
	ld a, [wIntroMapDelayStep]
	cp 20 ; Delay for a few frames to avoid A button spam
	jr z, .doneDelaying
	inc a ; Acknowledge one frame of delay
	ld [wIntroMapDelayStep], a
	cp 10 ; Halfway through, apply gray to a player
	ret nz
	; Gray out Tom
	xor a
	ld [hOverworldPressedButtons], a ; Make sure no action will be taken
	jr .toggleGender ; Gender loaded by default save file is Tom, so this will gray him out
	
.doneDelaying ; Run actual code
	ld a, [wPlayerGender]
	and a ; Z = Evie
	ldh a, [hPressedButtons]
	ldh [hOverworldPressedButtons], a
	jr nz, .checkLeft ; Tom checks DPAD_LEFT, Evie checks DPAD_RIGHT
	add a, a ; Roll DPAD_RIGHT into DPAD_LEFT
.checkLeft
	and DPAD_LEFT ; Check if player has pressed the button that changes gender
	jr z, .dontToggleGender
	
.toggleGender ; Hook for above
	callacross ReloadPalettes ; Cancel previous "gray" effect (this is overkill but smaller code than reloading only the two palettes)
	ld hl, wPlayerGender
	ld a, [hl] ; Retrieve currently chosen gender
	ld e, a ; Store it for gray out effect
	xor 1 ; Flip gender
	ld [hl], a
	
	; Little explanation here :
	; There are 2 palettes per player
	; 1 palette is 4 colors
	; In the GBC's memory, 1 color is 2 bytes large (post-processed size)
	; In the game's storage, 1 color is 3 bytes large (pre-processing size)
	; Thus, there are 2 * 4 * 2 bytes = 16 bytes per player in the GBC's memory
	;   and there are 2 * 4 * 3 bytes = 24 bytes per player in the game's storage
	
	; e = gender
	swap e ; e = gender * 16
	ld a, e
	add a, $80 | 32 ; This sets the base offset and sets the auto-increment bit
	ld [rBGPI], a
	ld a, e ; e = gender * 16
	rrca ; a = gender * 8
	add a, e ; a = gender * 24
	ld hl, wBGPalette4_color0
	add a, l
	ld l, a
	
	; Coming right up is graying out the two palettes of the character that's not chosen
	ld e, 8 ; Two palettes, thus 8 colors
.grayOutOneColor
	; Recipe to gray out a color :
	; 1. Sum the three shades in the color (R, G, B)
	; 2. Divide that by 3, thusly getting the mean of the shades
	; 3. Write that shade as the R, G and B shades
	; Explanation : step 3 produces a grey color.
	; Steps 1 and 2 ensure it's as close to the original color as possible.
	; (It's probably possible to do slightly better in some cases, but this looks good enough)
	ld a, [hli] ; Step 1 : sum
	add [hl]
	inc hl
	add [hl]
	inc hl
	call DivideBy3 ; Step 2 : divide by 3
	ld a, c ; Step 2.5 : we're going to darken the "inactive" character to emphasis a bit on it being "inactive"
	cp $1F
	jr z, .dontCap ; Don't darken white, it creates a weird outline (and doesn't make sense visually)
	sub 4 ; Remove some intensity, this is purely arbitrary, but heh
	jr nc, .dontCap
	xor a
.dontCap
	ld c, a ; Step 3 : convert the 3-byte format into the GBC's 2-byte one
	and %111 ; Not going to comment it. You can easily figure it out.
	rrca
	rrca
	rrca
	or c
	ld d, a ; Store for later
	ld a, c
	and %11000
	rlca
	rlca
	rlca
	or c
	rlca
	rlca
	ld c, a
.waitVRAM
	rst isVRAMOpen
	jr nz, .waitVRAM
	ld a, d
	ld [rBGPD], a ; We write both bytes as shortly as possible to avoid doing so on different scanlines,
	ld a, c
	ld [rBGPD], a ; which produces "parasitic" colors (even more since the green shade is split across both bytes)
	dec e
	jr nz, .grayOutOneColor
	
.dontToggleGender
	ldh a, [hOverworldPressedButtons]
	and BUTTON_A | BUTTON_START | BUTTON_SELECT
	ret z ; Don't advance status if A or START or SELECT aren't pressed
	
	; Gender has been chosen!
	inc b
	ld a, b
	ld [wIntroMapStatus], a ; Advance status
	
	xor a ; Reset the delay counter for the following statuses
	ld [wIntroMapDelayStep], a
	
	; Apply gray effect to the palette in the palette array, otherwise color will suddenly re-appear during fade-out
	ld hl, wBGPalette4_color0
	ld a, [wPlayerGender]
	and a
	jr nz, .grayTom
	ld l, wBGPalette6_color0 & $FF
.grayTom
	ld b, 4 * 2 ; Gray two palettes, ie. 2 times 4 colors
.grayOneColor
	ld a, [hli]
	add a, [hl]
	inc hl
	add a, [hl]
	dec hl
	dec hl
	call DivideBy3
	ld a, c
	cp $1F
	jr z, .dontDarken
	sub 4
	jr nc, .dontDarken ; If there is an underflow, "cap" at black
	xor a
.dontDarken
	ld c, 3
	rst fill
	dec b
	jr nz, .grayOneColor
	
	ld a, [wPlayerGender]
	and a
	ret nz ; Tom's gfx are loaded by default, don't reload if it's still Tom
	jpacross LoadPlayerGraphics
	
IntroFadeToNarrator::
	inc b
	ld a, b
	ld [wIntroMapStatus], a
	ld a, 1
	ldh [hIgnorePlayerActions], a
	; Reload map with warp-to #1
	ld [wTargetWarpID], a ; Which sets things for the "tutorial" part instead of the "charselect" one
	inc a
	jp LoadMap
	
IntroResetDelayStep::
	; Check if player is still at its starting position
	; If warp-to #1's position is modified, update these accordingly
	ld a, [wYPos]
	cp TUTORIAL_STARTING_YPOS
	jr nz, .playerMoved
	
	ld a, [wXPos]
	cp TUTORIAL_STARTING_XPOS
	ret z
	
.playerMoved
	inc b
	ld a, b
	ld [wIntroMapStatus], a
	ret
	
IntroWaitNextState::
	ld a, [wIntroMapDelayStep] ; Holds the frame count when entering this state, used to determine when 256 frames have passed
	and a
	ld c, a
	ldh a, [hOverworldFrameCounter]
	; Will trigger twice if the frame counter to be stored is 0
	; Except when TASing this game, it wouldn't be a problem :D
	jr z, .setDelayStep ; Step is uninitialized, 
	
	cp c ; Check if 256 frames passed (~ 4 seconds)
	ret nz ; Nope
	
	ld a, [wIntroMapStatus]
	bit 6, a ; Check if 256 frames had already passed
	
	ld c, $40
	jr z, .first256block ; We're on the 256th frame, set the status flag to remember it
	; We're on the 512th frame, go to next state
	ld c, $1 - $40
.first256block
	
	add a, c
	ld [wIntroMapStatus], a
	ret
	
.setDelayStep
	ld [wIntroMapDelayStep], a
	ret
	
IntroCheckStartMenu::
	ld a, [wIntroMapStatus] ; Check bit 7, which is set if player answered "no" to previous text
	add a, a
	jr c, .playerTooSmart
	ldh a, [hPressedButtons]
	bit 3, a
	ret z
	ld de, IntroStartMenuText
	ld c, BANK(IntroStartMenuText)
	callacross ProcessText_Hook
	ld a, 3
	ld [wFadeSpeed], a
	
.playerTooSmart
	ld a, $F9
	ldh [hOverworldButtonFilter], a
	pop bc ; Remove the return address, otherwise LoadMap will return with the wrong ROM bank. Also, switching RAM banks back is done by LoadMap anyways
	ld a, 1
	ldh [hIgnorePlayerActions], a
	
	ld [wTargetWarpID], a ; Go to the test map's warp #1
	xor a
	jp LoadMap
	

SECTION "Intro map texts", ROMX
	
IntroTexts::

IntroBoyGirlText::
	print_pic GameTiles
	print_name GameName
	print_line .line0
	print_line .line1
	print_line .line2
	wait_user
	clear_box
	print_line .line3
	print_line .line4
	print_line .line5
	wait_user
	clear_box
	print_line .line6
	delay 60
	print_line .line7
	wait_user
	clear_box
	print_line .line8
	wait_user
	print_line .line9
	print_line .line10
	print_line .line11
	wait_user
	done
	
.line0
	dstr "BEFORE YOU CAN"
.line1
	dstr "EMBARK ON THIS"
.line2
	dstr "ADVENTURE..."
.line3
	dstr "I MUST ASK"
.line4
	dstr "A COUPLE OF"
.line5
	dstr "QUESTIONS."
.line6
	dstr "THE TOPIC?"
.line7
	dstr "YOU."
.line8
	db "FOR EXAMPLE,", 0
.line9
	dstr "I NEED TO KNOW"
.line10
	dstr "IF YOU ARE A"
.line11
	dstr "BOY OR GIRL."
	
	
IntroChoseGenderText::
	print_pic GameTiles
	print_name GameName
	print_line .line0
	wait_user
	clear_box
	print_line .line1
	print_line .line2
	print_line .line3
	wait_user
	clear_box
	print_line .line4
	print_line .line5
	wait_user
	end_with_box
	
.line0
	dstr "OKAY!"
.line1
	dstr "I'LL LEAVE YOU"
.line2
	dstr "WITH THE"
.line3
	dstr "NARRATOR."
.line4
	dstr "SEE YOU AND"
.line5
	dstr "HAVE FUN!"
	
	
IntroGreetText::
	disp_box
	delay 60
	print_line .line0
	wait_user
	clear_box
	print_line .line1
	print_line .line2
	wait_user
	clear_box
	print_line .line3
	wait_user
	clear_box
	print_line .line4
	print_line .line5
	wait_user
	done
	
.line0
	dstr "Ah."
.line1
	dstr "Someone has"
.line2
	dstr "arrived."
.line3
	dstr "Then hello."
.line4
	dstr "Use the d-pad"
.line5
	dstr "to move around."
	
	
IntroPressAText::
	delay 5
	disp_box
	print_line .line0
	delay 60
	print_line .line1
	print_line .line2
	print_line .line3
	wait_user
	done
	
.line0
	db "Okay, "
	dstr "good."
.line1
	dstr "Press A to"
.line2
	dstr "interact with"
.line3
	dstr "other things."
	
	
IntroObjectNeededText::
	disp_box
	print_line .line0
	print_line .line1
	wait_user
	clear_box
	print_line .line2
	print_line .line3
	delay 20
.source1
	choose YesNoChoice, (.branch1 - .source1)
	clear_box
	print_line .line4
	delay 60
	clear_box
	print_line .line5
	wait_user
	print_line .line6
	print_line .line7
	print_line .line8
	wait_user
	delay 30
	text_lda_imm $00
	text_sta wNPC1_ypos + 1
	text_lda wXPos ; Check if player might intersect NPC
	text_cmp $60
.source2
	text_jr cond_c, (.branch2 - .source2)
	text_lda_imm $50 ; If yes, move NPC to prevent this
	text_sta wNPC1_xpos
.branch2
	text_asmcall ProcessNPCs
	text_lda_imm $F1
	text_sta hOverworldButtonFilter
	delay 30
	print_line .line9
	wait_user
	done
	
.branch1
	clear_box
	delay 20
	print_line .line10
	delay 50
	print_line .line11
	delay 50
	wait_user
	clear_box
	print_line .line12
	print_line .line13
	print_line .line14
	wait_user
	clear_box
	print_line .line15
	text_bankswitch BANK(wIntroMapStatus)
	text_lda_imm $8B ; Set bit 7 to flag player as "too smart" and advance to last status
	text_sta wIntroMapStatus
	text_bankswitch 1
	delay 60
	print_line .line16
	wait_user
	done
	
	
.line0
	dstr "Why aren't you"
.line1
	dstr "interacting?"
.line2
	dstr "Are you even"
.line3
	dstr "trying?"
.line4
	dstr "..."
.line5
	db "Well, yes,", 0
.line6
	dstr "maybe you need"
.line7
	dstr "something to"
.line8
	dstr "interact with."
.line9
	dstr "Okay. Now go."
	
.line10
	dstr "Oooh."
.line11
	dstr "I get it!"
.line12
	dstr "So you think"
.line13
	dstr "you're smarter"
.line14
	dstr "than ME?"
.line15
	dstr "Very well."
.line16
	dstr "Get outta here."
	
	
IntroRemovedNPCText::
	text_lda_imm $FF
	text_sta wNPC1_ypos
	text_asmcall ProcessNPCs
	delay 20
	disp_box
	print_line .line0
	print_line .line1
	wait_user
	clear_box
	print_line .line2
	print_line .line3
	wait_user
	done
	
.line0
	db "Okay, "
	dstr "enough"
.line1
	dstr "shenanigans."
.line2
	dstr "Press START to"
.line3
	dstr "open your menu."
	
	
IntroStartMenuText::
	disp_box
	print_line .line0
	print_line .line1
	print_line .line2
	wait_user
	print_line .line3
	print_line .line4
	print_line .line5
	wait_user
	clear_box
	print_line .line6
	print_line .line7
	wait_user
	instant_str .endingLines
	done
	
.line0
	db "Okay, "
	dstr "you know"
.line1
	dstr "what the START"
.line2
	dstr "button is."
.line3
	dstr "It's not my job to"
.line4
	dstr "explain this"
.line5
	dstr "crappy menu."
.line6
	dstr "You're on your"
.line7
	db "own, "
	dstr "get it?"
.endingLines
	dstr "Man I hate"
	dstr "this job."
	db 0

