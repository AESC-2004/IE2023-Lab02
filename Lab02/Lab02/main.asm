;
; Lab02.asm
;
; Created: 10/02/2025 17:36:05
; Author : ang50
;

.include "M328PDEF.inc"
.cseg
.org 0x0000
	RJMP	RESET

.org 0x0020

;Establecer dirección en program mem.
DISP7SEG:	
	.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;Definición de registros importantes
.def	BIN0		= R23
.def	BIN0temp	= R22

SETUP:
	;Establecemos el ZPointer en la dirección de DISP7SEG
	RESET:
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	
	;Configurar STACK
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	;Deshabilitar serial (Importante; se utilizará PD para el display)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	;Configurar I/O PORTS (DDRx, PORTx)
	;PORTD: BIN0 Out (PD0,1,2,3,4,5,6)	|	PORTD: 0XXXXXXX
	LDI		R16, 0b11111111
	OUT		DDRD, R16
	LDI		R16, 0b00000000
	OUT		PORTD, R16
	;PORTC: BIN0 In (PC0,1)				|	PORTC: 00000011
	LDI		R16, 0x00
	OUT		DDRC, R16
	LDI		R16, 0b00000011
	OUT		PORTC, R16

	;Valores iniciales de registros importantes
	LDI		BIN0, 0x00
	LPM		BIN0temp, Z
	OUT		PORTD, BIN0temp



MAIN:
	;Revisando si se quiere modificar BIN0
	SBIS	PINC, PINC1			;Skip-next-line si el BIN0-UP-Button NO es presionado (Logic 1)
	CALL	BIN0_UP_SEG			;Si BIN0-UP-Button SI es presionado (Logic 0), CALL su sub-rutina de seguridad
	SBIS	PINC, PINC0			;Skip-next-line si el BIN0-DWN-Button NO es presionado (Logic 1)
	CALL	BIN0_DWN_SEG		;Si BIN0-DWN-Button SI es presionado (Logic 0), CALL su sub-rutina de seguridad
	JMP		MAIN				;Ciclo infinito



;Sub-rutinas de BIN0
BIN0_UP_SEG:			;Rutina de seguridad de presionado de BIN0-UP-Button
	CALL	DELAY		;Llamamos al Delay...
	;Si al regresar, BIN0-UP-Button SIGUE presionado (Logic 0), realizamos el aumento en BIN0
	;Si al regresar, BIN0-UP-Button NO SIGUE presionado (Logic 1), fue botonazo y regresamos a MAIN
	SBIC	PINC, PINC1		
	RET
	CALL	BIN0_UP
	;Si luego de aumentar BIN0, BIN0-UP-Button SIGUE presionado, loopeamos hasta que se deje de presionar
	;Si luego de aumentar BIN0, BIN0-UP-Button NO SIGUE presionado (O ya no es presionado en el loop), regresamos a MAIN
	BIN0_UP_LOOP:
		SBIS	PINC, PINC1
		RJMP	BIN0_UP_LOOP
	RET
BIN0_UP:				;Rutina de aumento de BIN0
	;Incrementamos BIN0
	;Si hay carry (4to bit encendido), limpiamos BIN0 (BIN0_CLR)
	;Si no hay carry, "arreglamos" BIN0temp con el valor de ZP para subir a PORTD (BIN0_DWN_7SEG)
	;Recordar que PORTD: 0XXXXXXX 
	INC		BIN0
	SBRC	BIN0, 4
	JMP		BIN0_CLR
	JMP		BIN0_UP_7SEG
	RETURN_UP:
	RET

	BIN0_CLR:
	;Limpiamos BIN0
	;Cargamos la primera localidad de DISP7SEG a ZPointer
	;Cargamos en BIN0temp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BIN0temp a PD
	CLR		BIN0
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	LPM		BIN0temp, Z
	OUT		PORTD, Bin0temp
	JMP		RETURN_UP
	BIN0_UP_7SEG:
	;Aumentamos el valor de ZPointer para que apunte al valor deseado de DISP7SEG
	;Cargamos en BIN0temp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BIN0temp a PD
	ADIW	Z, 1
	LPM		BIN0temp, Z
	OUT		PORTD, Bin0temp
	JMP		RETURN_UP



BIN0_DWN_SEG:			;Rutina de seguridad de presionado de BIN0-DWN-Button
	CALL	DELAY		;Llamamos al Delay...
	;Si al regresar, BIN0-DWN-Button SIGUE presionado (Logic 0), realizamos el decremento en BIN0
	;Si al regresar, BIN0-DWN-Button NO SIGUE presionado (Logic 1), fue botonazo y regresamos a MAIN
	SBIC	PINC, PINC0		
	RET
	CALL	BIN0_DWN
	;Si luego de decrementar BIN0, BIN0-DWN-Button SIGUE presionado, loopeamos hasta que se deje de presionar
	;Si luego de decrementar BIN0, BIN0-DWN-Button NO SIGUE presionado (O ya no es presionado en el loop), regresamos a MAIN
	BIN0_DWN_LOOP:
		SBIS	PINC, PINC0
		RJMP	BIN0_DWN_LOOP
	RET
BIN0_DWN:				;Rutina de decremento de BIN0
	;Decrementamos BIN0
	;Si hay carry (7mo bit encendido), corregimos BIN0 (BIN0_SET)
	;Si no hay carry, "arreglamos" BIN0temp con el valor de ZP para subir a PORTD (BIN0_DWN_7SEG)
	;Recordar que PORTD: 0XXXXXXX 
	DEC		BIN0
	SBRC	BIN0, 7
	JMP		BIN0_SET
	JMP		BIN0_DWN_7SEG
	RETURN_DWN:
	RET

	BIN0_SET:
	;Corregimos BIN0
	;Cargamos la última localidad de DISP7SEG a ZPointer
	;Cargamos en BIN0temp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BIN0temp a PD
	LDI		BIN0, 0x0F
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	ADIW	Z, 15
	LPM		BIN0temp, Z
	OUT		PORTD, Bin0temp
	JMP		RETURN_DWN

	BIN0_DWN_7SEG:
	;Decrementamos el valor de ZPointer para que apunte al valor deseado de DISP7SEG
	;Cargamos en BIN0temp el valor contenido en la dirección a la que apunta ZPointer
	;Subimos BIN0temp a PD
	SBIW	Z, 1
	LPM		BIN0temp, Z
	OUT		PORTD, Bin0temp
	JMP		RETURN_DWN



;Sub-rutinas de DELAY
DELAY:					
	LDI		R18, 0x00
	RET



