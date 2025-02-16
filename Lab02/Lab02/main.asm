;
; Lab02.asm
;
; Created: 10/02/2025 17:36:05
; Author : ang50
;

.include "M328PDEF.inc"
.cseg

;Establecer dirección en program mem. LUEGO de los vectores de interrupción
.org 0x0020
DISP7SEG:	
	.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;Definición de registros importantes
.def	BINDISP			= R23
.def	BINDISPtemp		= R22
.def	COUNTMILLIS		= R24
.def	BINSECS			= R20
.def	BINSECStemp		= R21

SETUP:
	;Establecemos el ZPointer en la dirección de DISP7SEG
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	
	;Configurar STACK
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	;Configurar Prescaler "Global" de 16 (DATASHEET P.45)	|	16MHz a 1MHz
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16
	LDI		R16, (1 << CLKPS2)
	STS		CLKPR, R16

	;Deshabilitar serial (Importante; se utilizará PD para el display)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	;Configurar I/O PORTS (DDRx, PORTx)
	;PORTB: BINSECS & STATE Out (PB0,1,2,3,4)	|	PORTB: 000XXXXX
	LDI		R16, 0b00011111
	OUT		DDRB, R16
	LDI		R16, 0b00000000
	OUT		PORTB, R16
	;PORTD: BINDISP Out (PD0,1,2,3,4,5,6)		|	PORTD: 0XXXXXXX
	LDI		R16, 0b11111111
	OUT		DDRD, R16
	LDI		R16, 0b00000000
	OUT		PORTD, R16
	;PORTC: BINDISP In (PC0,1)					|	PORTC: 00000011
	LDI		R16, 0x00	
	OUT		DDRC, R16
	LDI		R16, 0b00000011
	OUT		PORTC, R16

	;Valores iniciales de registros importantes
	LDI		COUNTMILLIS, 0x00
	LDI		BINSECS, 0x00
	LDI		BINDISP, 0x00
	LPM		BINDISPtemp, Z
	OUT		PORTD, BINDISPtemp

	;Config. de TIMER0 en modo NORMAL
	;Sin necesidad de cambiar TCCR0A
	LDI		R16, (1 << CS02) | (1 << CS00)		;Prescaler 1024
	OUT		TCCR0B, R16



MAIN_LOOP:
	;Si BINDISP = 0: NO aumentar BINSECS y apagar LED
	CPI		BINDISP, 0
	IN		R16, SREG		
	SBRC	R16, 1
	JMP		BINSECS_AND_LED_OFF

	;Verificar si han transcurrido 100ms y aumentar COUNTMILLIS
	;Si TCNT0 = 0: Han transcurrido 100ms
	IN		R16, TCNT0
	CPI		R16, 0
	IN		R17, SREG
	SBRC	R17, 1
	CALL	TIM0_SET_AND_COUNTMILLIS_UP

	;Si COUNTMILLIS = 10: Aumentar BINSECS y reiniciar COUNTMILLIS
	CPI		COUNTMILLIS, 10
	IN		R16, SREG		
	SBRC	R16, 1
	CALL	BINSECS_UP_AND_COUNTMILLIS_CLR

	;Revisando si BINSECS = BINDISP
	CP		BINSECS, BINDISP
	IN		R16, SREG		
	SBRC	R16, 1
	CALL	STATE_CHANGE_AND_BINSECS_CLEAR

	;Revisando si se quiere modificar BINDISP
	BUTTONS:
		SBIS	PINC, PINC1			;Skip-next-line si el BINDISP-UP-Button NO es presionado (Logic 1)
		CALL	BINDISP_UP_SEG		;Si BINDISP-UP-Button SI es presionado (Logic 0), CALL su sub-rutina de seguridad
		SBIS	PINC, PINC0			;Skip-next-line si el BINDISP-DWN-Button NO es presionado (Logic 1)
		CALL	BINDISP_DWN_SEG		;Si BINDISP-DWN-Button SI es presionado (Logic 0), CALL su sub-rutina de seguridad
		JMP		MAIN_LOOP			;Ciclo infinito

	BINSECS_AND_LED_OFF:
		;Si BINDISP = 0: NO aumentar BINSECS y apagar LED
		LDI		BINSECS, 0
		LDI		BINSECStemp, 0
		OUT		PORTB, BINSECStemp
		;Saltamos a revisar botones sin revisar si transcurrieron 100ms
		JMP		BUTTONS



;********Sub-rutinas NO de interrupción********
;Sub-rutinas del temporizador y de sus contadores asociados
TIM0_SET_AND_COUNTMILLIS_UP:
	;Config. de TIMER0 en temporizador NORMAL (100ms)
	;Compare value: TCNT0 = 256-98 = 158
	LDI		R16, 158
	OUT		TCNT0, R16
	INC		COUNTMILLIS
	RET
BINSECS_UP_AND_COUNTMILLIS_CLR:
	;Si COUNTMILLIS = 10: Ha transcurrido 1s
	;Incrementamos BINSECS
	;"Ajustamos" BINSECS en BINSECStemp para subir a PORTB
	CLR		COUNTMILLIS
	INC		BINSECS
	SBRC	BINSECS, 4
	CLR		BINSECS
	IN		R16, PORTB
	BST		R16, 4
	MOV		BINSECStemp, BINSECS
	BLD		BINSECStemp, 4
	OUT		PORTB, BINSECStemp
	RET
STATE_CHANGE_AND_BINSECS_CLEAR:
	;Si BINSECS = BINDISP, reiniciar BINSECS y cambiar estado de LED
	CLR		BINSECS
	IN		R16, PORTB
	BST		R16, 4
	MOV		BINSECStemp, BINSECS
	BLD		BINSECStemp, 4
	OUT		PORTB, BINSECStemp
	SBI		PINB, PINB4
	RET
BINSECS_CLEAR_AND_LED_ON:
	;Si se presionó un botón, reiniciamos BINSECS y encendemos el LED
	CLR		BINSECS
	LDI		BINSECStemp, 0b00010000
	OUT		PORTB, BINSECStemp
	RET



;Sub-rutinas de BINDISP
BINDISP_UP_SEG:			;Rutina de seguridad de presionado de BINDISP-UP-Button
	;Incrementamos BINDISP
	;Si hay carry (4to bit encendido), limpiamos BINDISP (BINDISP_CLR)
	;Si no hay carry, "arreglamos" BINDISPtemp con el valor de ZP para subir a PORTD (BINDISP_DWN_7SEG)
	;Recordar que PORTD: 0XXXXXXX 
	INC		BINDISP
	SBRC	BINDISP, 4
	JMP		BINDISP_CLR
	JMP		BINDISP_UP_7SEG
	;Si luego de aumentar BINDISP, BINDISP-UP-Button SIGUE presionado, loopeamos hasta que se deje de presionar
	;Si luego de aumentar BINDISP, BINDISP-UP-Button NO SIGUE presionado (O ya no es presionado en el loop), regresamos a MAIN_LOOP
	BINDISP_UP_LOOP:
		CALL	BINSECS_CLEAR_AND_LED_ON
		SBIS	PINC, PINC1
		RJMP	BINDISP_UP_LOOP
	RET
	BINDISP_CLR:
	;Limpiamos BINDISP
	;Cargamos la primera localidad de DISP7SEG a ZPointer
	;Cargamos en BINDISPtemp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BINDISPtemp a PD
	CLR		BINDISP
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	LPM		BINDISPtemp, Z
	OUT		PORTD, BINDISPtemp
	JMP		BINDISP_UP_LOOP
	BINDISP_UP_7SEG:
	;Aumentamos el valor de ZPointer para que apunte al valor deseado de DISP7SEG
	;Cargamos en BINDISPtemp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BINDISPtemp a PD
	ADIW	Z, 1
	LPM		BINDISPtemp, Z
	OUT		PORTD, BINDISPtemp
	JMP		BINDISP_UP_LOOP

BINDISP_DWN_SEG:			;Rutina de seguridad de presionado de BINDISP-DWN-Button
	;Decrementamos BINDISP
	;Si hay carry (7mo bit encendido), corregimos BINDISP (BINDISP_SET)
	;Si no hay carry, "arreglamos" BINDISPtemp con el valor de ZP para subir a PORTD (BINDISP_DWN_7SEG)
	;Recordar que PORTD: 0XXXXXXX 
	DEC		BINDISP
	SBRC	BINDISP, 7
	JMP		BINDISP_SET
	JMP		BINDISP_DWN_7SEG
	;Si luego de decrementar BINDISP, BINDISP-DWN-Button SIGUE presionado, loopeamos hasta que se deje de presionar
	;Si luego de decrementar BINDISP, BINDISP-DWN-Button NO SIGUE presionado (O ya no es presionado en el loop), regresamos a MAIN_LOOP
	BINDISP_DWN_LOOP:
		CALL	BINSECS_CLEAR_AND_LED_ON
		SBIS	PINC, PINC0
		RJMP	BINDISP_DWN_LOOP
	RET
	BINDISP_SET:
	;Corregimos BINDISP
	;Cargamos la última localidad de DISP7SEG a ZPointer
	;Cargamos en BINDISPtemp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BINDISPtemp a PD
	LDI		BINDISP, 0x0F
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	ADIW	Z, 15
	LPM		BINDISPtemp, Z
	OUT		PORTD, BINDISPtemp
	JMP		BINDISP_DWN_LOOP
	BINDISP_DWN_7SEG:
	;Decrementamos el valor de ZPointer para que apunte al valor deseado de DISP7SEG
	;Cargamos en BINDISPtemp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BINDISPtemp a PD
	SBIW	Z, 1
	LPM		BINDISPtemp, Z
	OUT		PORTD, BINDISPtemp
	JMP		BINDISP_DWN_LOOP





