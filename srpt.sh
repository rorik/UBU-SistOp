#! /bin/bash
# Simula la ejeución de una serie de procesos en un algoritmo SRPT
# AUTHOR: Rodrigo Díaz, Diego González
# LICENSE: MIT

if ! [[ (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -eq 3 && ${BASH_VERSINFO[2]} -ge 48) || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -gt 3) || ${BASH_VERSINFO[0]} -gt 4 ]]; then read -n 1 -p "VERSIÓN DE BASH < 4.3.48, la ejecución en esta versión no ha sido testeada, ¿continuar (s/n)? "; [[ ! $REPLY =~ ^[SsYy] ]] && echo && exit 90; fi
if [[ $(tput cols) -lt 90 ]]; then read -n 1 -p "El programa esta diseñado para funcionar con una ventana de al menos 90 caracteres de ancho, ¿continuar (s/n)? "; [[ ! $REPLY =~ ^[SsYy] ]] && echo && exit 91; fi

#_____________________________________________
# COMIENZO DE FUNCIONES
#_____________________________________________

#######################################
#	Muestra cabeceras gráficas
#	Globales:
#		mem_tamano
#		mem_tamano_abreviacion
#		mem_tamano_redondeado
#		mem_usada
#		mem_usada_abreviacion
#		mem_usada_redondeado
#		modo_silencio
#		proc_count
#		proc_count_abreviacion
#		proc_count_redondeado
#		tiempo
#	Argumentos:
#		modo:
#			0 = linea separación
#			1 = cabecera principal
#			2 = cabecera secundaria
#		salida:
#			0 = pantalla y log
#			1 = pantalla
#			2 = log
#	Devuelve:
#   Texto
#######################################
function header() {
	local -ri modo=$1 salida=$2
	local linea linea_no_esc linea_buffer
	if [[ $modo -eq 0 ]]; then
		linea=
		linea_no_esc=
		for i in {17..21} {21..17} ; do
			linea+="\e[38;5;${i}m#########"
			linea_no_esc+='#########'
		done
		if [[ $salida -eq 0 ]]; then
			pantalla "$linea"; log 3 "$linea" "$linea_no_esc"
		elif [[ $salida -eq 1 ]]; then
			pantalla "$linea"
		else
			log 3 "$linea" "$linea_no_esc"
		fi
	elif [[ $modo -eq 1 ]]; then
		linea=
		if [[ -z $modo_silencio ]]; then clear && clear; fi
		header 0 $salida
		linea='\e[38;5;17m#\e[0m            \e[48;5;17m ALGORITMO SRPT, PAGINACIÓN FIFO, MEMORIA CONTINUA Y REUBICABLE\e[0m             \e[38;5;17m#'
		pantalla "$linea"
	else
		header 1 $salida
		linea='\e[38;5;17m#\e[0m           \e[48;5;17mMemoria: '
		if [[ -z $mem_usada_abreviacion ]]; then
			linea+=$(printf " %3d/" "$mem_usada_redondeado")
		else
			linea+=$(printf "%3d%1s/" "$mem_usada_redondeado" "$mem_usada_abreviacion")
		fi
		if [[ -z $mem_tamano_abreviacion ]]; then
			linea+=$(printf "%3d\e[0m " "$mem_tamano_redondeado")
		else
			linea+=$(printf "%3d%1s\e[0m" "$mem_tamano_redondeado" "$mem_tamano_abreviacion")
		fi
		linea+=$(printf "       \e[48;5;17mTiempo: %3d\e[0m      \e[48;5;17mNúmero de Procesos: " "$tiempo")
		if [[ -z $proc_count_abreviacion ]]; then
			linea+=$(printf " %3d" "$proc_count_redondeado")
		else
			linea+=$(printf "%3d%1s" "$proc_count_redondeado" "$proc_count_abreviacion")
		fi
		linea+='\e[0m           \e[38;5;17m#'
		pantalla "$linea"
		log 3 "$(printf "\e[38;5;17m#\e[39m%37sINSTANTE: %3d%38s\e[38;5;17m#\e[39m" " " "$tiempo" " ")" "$(printf "#%37sINSTANTE: %3d%38s#" " " "$tiempo" " ")"
		header 0
	fi
}

#######################################
#	Solicita datos al usuario
#	Globales:
#		mem_tamano
#		proc_color
#		proc_color_secuencia
#		proc_count
#		proc_estado
#		proc_id
#		proc_pagina_tamano
#		proc_paginas
#		proc_tamano
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_esperado
#		proc_tiempo_ejecucion_restante
#		proc_tiempo_llegada
#		tiempo_final
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function pedirDatos() {
	local -i i finalizado
	pantalla
	if [[ -z $proc_color_secuencia ]]; then
		proc_color_secuencia=(1,0 2,0 3,0 4,0 5,0 6,0 7,0 23,0 88,0 92,0 123,0 147,0 202,0 222,0 243,0)
	fi

	if [[ -z $mem_tamano ]]; then #si el tamaño de memoria nulo
		until [[ $mem_tamano =~ ^[0-9]+$ ]] && [[ ! $mem_tamano -eq 0 ]]; do #hasta el tamaño de memoria empiece entre 0 y 9 Y sea diferente a 0 hacer...
			printf "\e[1A%80s\r" " " #imprimir 80 espacios en color 1A
			read -p "Tamaño (en marcos) de la memoria: " mem_tamano #te pide que escribas algo y eso eso va a ser el tamaño de memoria
			printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r" #te muestra en pantalla el texto y vuelve a la linea anterior
		done
		printf "%80s\n" " "
	fi

	if [[ -z $proc_pagina_tamano ]]; then
		until [[ $proc_pagina_tamano =~ ^[0-9]+$ ]] && [[ ! $proc_pagina_tamano -eq 0 ]]; do
			printf "\e[1A%80s\r" " "
			read -p "Direcciones por página: " proc_pagina_tamano
			printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
		done
		printf "%80s\n" " "
	fi

	if [[ -z $proc_id ]]; then
		for ((i=0; finalizado!=1; i++)); do
			until [[ ${proc_tamano[i]} =~ ^[0-9]+$ ]] && [[ ! ${proc_tamano[i]} -eq 0 ]] || [[ $finalizado -eq 1 ]]; do
				printf "\e[1A%80s\r" " "
				read -p "[P${i}] Marcos de página: " proc_tamano[$i]
				if [[ -z ${proc_tamano[i]} ]]; then finalizado=1; unset proc_tamano[$i]; fi
				printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
			done
			printf "%80s\n" " "

			until [[ ${proc_tiempo_llegada[i]} =~ ^[0-9]+$ ]] || [[ $finalizado -eq 1 ]]; do
				printf "\e[1A%80s\r" " "
				read -p "[P${i}] Tiempo de llegada: " proc_tiempo_llegada[$i]
				if [[ -z ${proc_tiempo_llegada[i]} ]]; then
					finalizado=1
					unset proc_tamano[$i]
					unset proc_tiempo_llegada[$i]
				fi
				printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
			done
			printf "%80s\n" " "

			until [[ -n ${proc_direcciones[i]} ]] || [[ $finalizado -eq 1 ]]; do
				printf "\e[1A%80s\r" " "
				read -p "[P${i}] Secuencia de direcciones: " proc_direcciones[$i]
				proc_direcciones[$i]=$(echo ${proc_direcciones[i]} | tr -d ' ')
				if [[ -z ${proc_direcciones[i]} ]]; then
					finalizado=1
					unset proc_tamano[$i]
					unset proc_tiempo_llegada[$i]
					unset proc_direcciones[$i]
				fi
				if [[ ${proc_direcciones[i]} =~ ([0-9]+,)*[0-9]+ ]]; then
					proc_direcciones[$i]="${BASH_REMATCH[0]}"
				else
					unset proc_direcciones[$i]
				fi
				if [[ -z ${proc_direcciones[i]} ]]; then
					printf "\e[91mINTRODUCE NÚMEROS SEPARADOS POR COMAS\e[39m\r"
				fi
			done
			printf "%80s\n" " "

			if [[ -z $finalizado ]]; then
				printf "\e[1A%80s\r" " "
				proc_paginas[$i]=$(convertirDireccion ${proc_direcciones[i]})
				proc_id[$i]="P${i}" #Si no tiene la id asignada le da una
				proc_estado[$i]=1
				if [[ $i -lt ${#proc_color_secuencia[@]} ]]; then
					proc_color[$i]="48;5;$(echo ${proc_color_secuencia[i]} | cut -d ',' -f2);38;5;$(echo ${proc_color_secuencia[i]} | cut -d ',' -f1)"
				else
					proc_color[$i]="48;5;$(shuf -i 0-256 -n 1);38;5;$(shuf -i 0-256 -n 1)"
				fi
				proc_tiempo_ejecucion[$i]=0
				proc_tiempo_ejecucion_esperado[$i]=$(echo ${proc_paginas[i]} | tr ',' ' ' | wc -w) #Asigna el tiempo rastante al numero de paginas
				proc_tiempo_ejecucion_restante[$i]=${proc_tiempo_ejecucion_esperado[i]}
				log 3 "Proceso \e[44m${i}\e[49m, con ID \e[44m${proc_id[i]}\e[49m, Secuencia \e[44m${proc_paginas[i]}\e[49m, Marcos \e[44m${proc_tamano[i]}\e[49m, Llegada \e[44m${proc_tiempo_llegada[i]}" "Proceso <${i}>, con ID <${proc_id[i]}>, Secuencia <${proc_paginas[i]}>, Marcos <${proc_tamano[i]}>, Llegada <${proc_tiempo_llegada[i]}>"
			else
				echo -ne '\e[1A'
				read -n 1 -p "Terminar introducción de datos (s/n)? "
				printf "\r%80s" " "
				if [[ ! $REPLY =~ ^[SsYy] ]]; then
					unset finalizado
					((i--))
				fi
			fi
		done
		proc_count=${#proc_id[@]}
		if [[ $proc_count -eq 0 ]]; then
			finalizarEjecucion 21
		fi
	fi
	tiempo_final="$(ultimoTiempo)"
}

#######################################
#	Lee argumentos de ejecución
#	Globales:
#		filename
#		mem_tamano
#		modo_debug
#		modo_silencio
#		nivel_log
#		proc_count
#		tiempo_break
#		tiempo_unbreak
#	Argumentos:
#		-b	TIEMPO
#			Habilita modo debug en TIEMPO
#		-d
#			Habilita modo debug
#		-f	FILENAME
#			Cargar datos desde FILENAME
#		-l	NIVEL
#			Nivel de salida por fichero:
#				0		debug
#				1		extendido
#				2		estructural
#				3		por defecto
#				4		alertas
#				5		mínimo
#				9		ejecición
#				10	deshabilitado
#		-m	MARCOS
#			Tamaño de memoria en marcos
#		-p	NÚMERO
#			Número de procesos
#		-s
#			Deshabilita salida por pantalla
#		-u	TIEMPO
#			Deshabilita modo debug en TIEMPO
#	Devuelve:
#		Nada
#######################################
function leerArgs() {
	while [[ $1 != "" ]]; do #mientras el parametro 1 no esté vacio
		case $1 in
			-s|--silencio) #si el parametro es s o silencio
				modo_silencio=1
				log 3 'Salida gráfica deshabilitada' '@';;
			-d|--debug)
				modo_debug=1
				nivel_log=0
				log 3 'Entrando modo debug' '@';;
			-f|--filename)
			  if [[ -n $2 ]] && [[ ! $2 == -* ]]; then
					filename=$2
					log 5 "Argumento de archivo introducido \e[44m$filename" "Argumento de archivo introducido <${filename}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--filename" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mfilename\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento filename contiene errores !!!'
					finalizarEjecucion 40
			  fi;;
			-m|--memoria)
			  if [[ -n $2 ]] && [[ ! $2 == -* ]]; then
					local -ri tmp_mem_tamano=$2
					log 5 "Argumento de memoria introducido \e[44m$tmp_mem_tamano" "Argumento de memoria introducido ${tmp_mem_tamano}"
					shift 2
					continue
			  else
					echo 'ERROR: "--memoria" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mmemoria\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento memoria contiene errores !!!'
					finalizarEjecucion 41
			  fi;;
			-p|--procesos)
			  if [[ -n $2 ]] && [[ ! $2 == -* ]]; then
					proc_count=$2
					log 5 "Argumento de procesos introducido \e[44m$proc_count" "Argumento de procesos introducido <${proc_count}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--procesos" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mprocesos\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento procesos contiene errores !!!'
					finalizarEjecucion 42
			  fi;;
			-l|--log)
			  if [[ -n $2 ]] && [[ ! $2 == -* ]]; then
					nivel_log=$2
				  log 5 "Establecido nivel de log a \e[44m$nivel_log" "Establecido nivel de log a <${nivel_log}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--log" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mlog\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento log contiene errores !!!'
					finalizarEjecucion 43
			  fi;;
				-b|--breakpoint)
					if [[ -n $2 ]] && [[ ! $2 == -* ]]; then
						tiempo_break=$2
						log 9 "Estableciendo breakpoint en \e[44m$tiempo_break" "Estableciendo breakpoint en <${tiempo_break}>"
						shift 2
						continue
				  else
						echo 'ERROR: "--breakpoint" requiere un argumento válido/no vacio.'
						log 9 '\e[91m!!!\e[39m El argumento \e[91mbreakpoint\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento breakpoint contiene errores !!!'
						finalizarEjecucion 44
				  fi;;
				-u|--unbreakpoint)
					if [[ -n $2 ]] && [[ ! $2 == -* ]]; then
						tiempo_unbreak=$2
						log 9 "Estableciendo unbreakpoint en \e[44m$tiempo_unbreak" "Estableciendo unbreakpoint en <${tiempo_unbreak}>"
						shift 2
						continue
				  else
						echo 'ERROR: "--unbreakpoint" requiere un argumento válido/no vacio.'
						log 9 '\e[91m!!!\e[39m El argumento \e[91munbreakpoint\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento unbreakpoint contiene errores !!!'
						finalizarEjecucion 45
				  fi;;
			-?*)
				log 4 "\e[93m^^^\e[39m Opcíon \e[44m${1}\e[49m desconocida \e[93m^^^\e[39m" "^^^ Opción ${1} desconocida ^^^";;
			*)
		  	break
	  esac
	  shift
	done
	if [[ -n "$filename" ]]; then
		log 3 "Leyendo archivo:" '@'
		leerArchivo
		log 0 "Fin Lectura archivo" '@'
	fi
	if [[ -n "$tmp_mem_tamano" ]]; then
		mem_tamano=$tmp_mem_tamano
		log 3 "Tamaño de memoria asignado a \e[44m$mem_tamano" "Tamaño de memoria asignado a <${mem_tamano}>"
	fi
}

#######################################
#	Lee datos de archivo
#	Globales:
#		filename
#		mem_tamano
#		proc_color
#		proc_color_secuencia
#		proc_count
#		proc_estado
#		proc_id
#		proc_pagina_tamano
#		proc_paginas
#		proc_tamano
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_esperado
#		proc_tiempo_ejecucion_restante
#		proc_tiempo_llegada
#		tiempo_final
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function leerArchivo() {
	local -i i=0
	if [[ ! -f $filename ]]; then
		echo "Archivo \"${filename}\" no válido."
		log 9 '\e[91m!!!\e[39m El archivo no existe \e[91m!!!\e[39m' '!!! El archivo no existe !!!'
		finalizarEjecucion 30
	fi
	IFS=$'\n'; set -f #Establece el valor de separacion como final de linea
	for line in $(<$filename); do
		line=$(echo $line | cut -d '#' -f1 | tr -d ' ' | tr -d '\r') #elimina los espacios (-d) y tr sustituye
		log 0 "Linea leida \e[44m$line" "Linea leida <${line}>"
		if [[ ! $line == +* ]] && [[ -n $line ]]; then #si la linea no empieza por # y + o no es nula entonces...
			proc_tamano[$i]=$(echo $line | cut -d ';' -f1) #guarda el tamaño, porque va cortando todolo separado por ; y coge la 1ª columna(-f1)
			proc_direcciones[$i]=$(echo $line | cut -d ';' -f2) #guarda las paginas
			proc_tiempo_llegada[$i]=$(echo $line | cut -d ';' -f3) #guarda el tiempo de llegada
			proc_id[$i]=$(echo $line | cut -d';' -f4) #guarda la id
			if [[ $i -lt ${#proc_color_secuencia[@]} ]]; then
				proc_color[$i]="48;5;$(echo ${proc_color_secuencia[$i]} | cut -d ',' -f2);38;5;$(echo ${proc_color_secuencia[$i]} | cut -d ',' -f1)"
			else
				proc_color[$i]="48;5;$(shuf -i 0-256 -n 1);38;5;$(shuf -i 0-256 -n 1)"
			fi
			log 0 'Es proceso:'
			log 0 "Tamaño \e[44m${proc_tamano[$i]}" "Tamaño <${proc_tamano[$i]}>"
			log 0 "Secuecia \e[44m${proc_paginas[$i]}" "Secuecia <${proc_paginas[$i]}>"
			log 0 "Llegada \e[44m${proc_tiempo_llegada[$i]}" "Llegada <${proc_tiempo_llegada[$i]}>"
			log 0 "ID \e[44m${proc_id[$i]}" "ID <${proc_id[$i]}>"
			if [[ -z ${proc_id[$i]} ]]; then
				proc_id[$i]="P${i}" #si el proceso no tiene id se le asigna uno por defecto
				log 0 "Nueva ID \e[44m${proc_id[$i]}" "Nueva ID <${proc_id[$i]}>"
			fi
			proc_estado[$i]=1
			proc_paginas[$i]=$(convertirDireccion ${proc_direcciones[$i]})
			proc_tiempo_ejecucion_esperado[$i]=$(echo ${proc_paginas[i]} | tr ',' ' ' | wc -w)
			proc_tiempo_ejecucion_restante[$i]=${proc_tiempo_ejecucion_esperado[i]}
			log 3 "Proceso \e[44m${i}\e[49m, con ID \e[44m${proc_id[$i]}\e[49m, Secuencia \e[44m${proc_paginas[$i]}\e[49m, Marcos \e[44m${proc_tamano[$i]}\e[49m, Llegada \e[44m${proc_tiempo_llegada[$i]}\e[49m" "Proceso <${i}>, con ID <${proc_id[$i]}>, Secuencia <${proc_paginas[$i]}>, Marcos <${proc_tamano[$i]}>, Llegada <${proc_tiempo_llegada[$i]}>"
			((i++))
		else
			if [[ $line == +* ]]; then
				log 0 'Es opción:' '@'
				case $(echo $line | tr -d '+' | cut -d ':' -f1) in
					"MEMORIA")
						mem_tamano=$(echo $line | cut -d ':' -f2)
						log 0 "de memoria \e[44m$mem_tamano" "de memoria <${mem_tamano}>"
						log 3 "Configuración, marcos de memoria \e[44m$mem_tamano" "Configuración, marcos de memoria <${mem_tamano}>";;
					"DIRECCIONES")
						proc_pagina_tamano=$(echo $line | cut -d ':' -f2)
						log 0 "de página \e[44m$proc_pagina_tamano" "de página <${proc_pagina_tamano}>"
						log 3 "Configuración, tamaño de pagina \e[44m$proc_pagina_tamano" "Configuración, tamaño de pagina <${proc_pagina_tamano}>";;
					"COLORES")
						IFS=';' read -r -a proc_color_secuencia <<< "$(echo $line | cut -d ':' -f2)"
						log 0 "de color \e[44m$proc_color_secuencia" "de página <${proc_color_secuencia}>"
						log 3 "Configuración, colores \e[44m$proc_color_secuencia" "Configuración, colores <${proc_color_secuencia}>";;
					*)
						echo 'CONFIGURACIÓN EN FICHERO NO VÁLIDA'
						log 9 "\e[91m!!!\e[39m Configuración en archivo no válida \e[91m!!!\e[39m" "!!! Configuración en archivo no válida !!!"
						finalizarEjecucion 31;;
				esac
			else log 0 'Es comentario' '@'; fi
		fi
	done
	set +f; unset IFS
	if [[ ! $i -eq 0 ]]; then
		proc_count=$i
	fi
}

#######################################
#	Convierte páginas a direcciones
#	Globales:
#		proc_pagina_tamano
#	Argumentos:
#		direcciones
#	Devuelve:
#		paginas
#######################################
function convertirDireccion() {
	local -r secuencia=$1
	local -a direcciones=()
	local paginas
	IFS=',' read -r -a direcciones <<< "$secuencia"
	for direccion in ${direcciones[@]}; do
		paginas+="$((direccion / proc_pagina_tamano)),"
	done
	echo "${paginas::-1}"
}

#######################################
#	Muestra datos por pantalla
#	Globales:
#		linea_tiempo
#		mem_paginas
#		mem_paginas_secuencia
#		mem_proc_id
#		mem_proc_index
#		mem_siguiente_ejecucion
#		out_proc_index
#		proc_color
#		proc_estado
#		proc_id
#		proc_orden
#		proc_paginas
#		proc_posicion
#		proc_tamano
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_esperado
#		proc_tiempo_ejecucion_restante
#		proc_tiempo_espera
#		proc_tiempo_respuesta
#		swp_proc_id
#		swp_proc_index
#		tiempo
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function salidaEjecucion() {
	local -i i j ultimo_cambio=0 offset
	local -a paginas
	local id estado estado_color linea linea_no_esc linea_buffer
	header 2
	linea='\e[38;5;17m#\e[39m     ID     T.LL  T.Ej  Mrcos  Estd   T.Rst T.CPU T.Esp T.Rsp  Pos       Paginas        \e[38;5;17m#\e[39m'
	linea_no_esc='#     ID     T.LL  T.Ej  Mrcos  Estd   T.Rst T.CPU T.Esp T.Rsp  Pos       Paginas        #'

	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"
	for i in ${proc_orden[@]}; do
		id=${proc_id[$i]:0:9}
		if [[ ${proc_estado[i]} -ge 16 ]]; then
			estado='FINL'
			estado_color='96'
		elif [[ ${proc_estado[i]} -ge 8 ]]; then
			estado='EJEC'
			estado_color='95'
		elif [[ ${proc_estado[i]} -ge 4 ]]; then
			estado='MEM '
			estado_color='92'
		elif [[ ${proc_estado[i]} -ge 2 ]]; then
			estado='ESPR'
			estado_color='93'
		else
			estado='NOLL'
			estado_color='91'
		fi

		for ((j=-3; j<=3; j++)); do
			if [[ $j -ge 0 ]]; then
				paginas[$j]=''
				paginas[$j]=$(echo ${proc_paginas[i]} | cut -d ',' -f $((proc_tiempo_ejecucion[i]+j+1)))
			elif [[ ${proc_tiempo_ejecucion[i]} -ge $((-j)) ]]; then
				paginas[$((9-j))]=$(echo ${proc_paginas[i]} | cut -d ',' -f $((proc_tiempo_ejecucion[i]+j+1)))
			else
				paginas[$((9-j))]=''
			fi
		done

		linea=$(printf "\e[38;5;17m#\e[39m \e[%sm%*s\e[0m%*s \e[%sm%3d\e[0m   \e[%sm%3d\e[0m   \e[%sm%3d\e[0m    \e[%sm%s\e[0m   \e[%sm%3d\e[0m   \e[%sm%3d\e[0m   \e[%sm%3d\e[0m   \e[%sm%3d\e[0m   \e[%sm%3d\e[0m  \e[%sm%2s\e[0m \e[%sm%2s\e[0m \e[%sm%2s\e[0m \e[4;%sm%2s\e[0m \e[%sm%2s\e[0m \e[%sm%2s\e[0m \e[%sm%2s\e[0m \e[38;5;17m#\e[39m" "${proc_color[i]}" "$(((${#id}+10)/2))" "$id" "$((5-${#id}/2))" " " "${proc_color[i]}" "${proc_tiempo_llegada[i]}" "${proc_color[i]}" "${proc_tiempo_ejecucion_esperado[i]}" "${proc_color[i]}" "${proc_tamano[i]}" "$estado_color" "$estado" "${proc_color[i]}" "${proc_tiempo_ejecucion_restante[i]}" "${proc_color[i]}" "${proc_tiempo_ejecucion[i]}" "${proc_color[i]}" "${proc_tiempo_espera[i]}" "${proc_color[i]}" "${proc_tiempo_respuesta[i]}" "${proc_color[i]}" "$(echo ${proc_posicion[i]} | cut -d ' ' -f1)" "${proc_color[i]}" "${paginas[12]}" "${proc_color[i]}" "${paginas[11]}" "${proc_color[i]}" "${paginas[10]}" "${proc_color[i]}" "${paginas[0]}" "${proc_color[i]}" "${paginas[1]}" "${proc_color[i]}" "${paginas[2]}" "${proc_color[i]}" "${paginas[3]}")
		linea_no_esc=$(printf "# %*s%*s %3d   %3d   %3d    %s   %3d   %3d   %3d   %3d   %3d  %2s %2s %2s>%2s<%2s %2s %2s #" "$(((${#id}+10)/2))" "$id" "$((5-${#id}/2))" " " "${proc_tiempo_llegada[i]}" "${proc_tiempo_ejecucion_esperado[i]}" "${proc_tamano[i]}" "$estado" "${proc_tiempo_ejecucion_restante[i]}" "${proc_tiempo_ejecucion[i]}" "${proc_tiempo_espera[i]}" "${proc_tiempo_respuesta[i]}" "$(echo ${proc_posicion[i]} | cut -d ' ' -f1)" "${paginas[12]}" "${paginas[11]}" "${paginas[10]}" "${paginas[0]}" "${paginas[1]}" "${paginas[2]}" "${paginas[3]}")
		pantalla "$linea"; log 3 "$linea" "$linea_no_esc"
	done
	header 0

	linea='\e[38;5;17m#\e[39m  '; linea_no_esc='#  '
	for i in {0..27}; do
		offset=$(echo ${proc_posicion[mem_paginas[i]]} | cut -d ' ' -f1)
		if [[ -n ${mem_paginas[$i]} ]] && [[ $i -lt $mem_tamano ]] && [[ $i -eq $((proc_paginas_apuntador[mem_paginas[i]] + offset)) ]]; then
			linea+="  \e[${proc_color[${mem_paginas[i]}]}mv\e[0m"; linea_no_esc+='  v'
		else
			linea+='   '; linea_no_esc+='   '
		fi
	done
	linea+='  \e[38;5;17m#\e[39m'; linea_no_esc+='  #'
	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"

	linea='\e[38;5;17m#\e[39m  '; linea_no_esc='#  '
	for i in {0..27}; do
		if [[ $i -lt $mem_tamano ]]; then
			if [[ $i -ne 0 ]] && ([[ ${mem_paginas[i]} -ne ${mem_paginas[((i - 1))]} ]] || ([[ -z ${mem_paginas[i]} ]] && [[ -n ${mem_paginas[((i - 1))]} ]])); then
				case $i in
					0|1|26|27) linea+='\e[38;5;17m';;
					[2-4]|[23-25]) linea+='\e[38;5;18m';;
					[5-7]|[20-22]) linea+='\e[38;5;19m';;
					*) linea+='\e[38;5;20m';;
				esac
				linea+='|'; linea_no_esc+='|'
			else
				linea+=' '; linea_no_esc+=' '
			fi
			if [[ -z ${mem_paginas[$i]} ]]; then
				linea+='\e[38;5;236m##\e[0m'; linea_no_esc+='##'
			elif [[ ${mem_paginas_secuencia[i]} -eq -1 ]]; then
				linea+="\e[${proc_color[${mem_paginas[i]}]}m##\e[0m"; linea_no_esc+='##'
			else
				linea+="$(printf "\e[${proc_color[${mem_paginas[i]}]}m%2d\e[0m" "${mem_paginas_secuencia[i]}")"; linea_no_esc+="$(printf "%2d" "${mem_paginas_secuencia[i]}")"
			fi
		else
			linea+='   '; linea_no_esc+='   '
		fi
	done
	linea+='  \e[38;5;17m#\e[39m'; linea_no_esc+='  #'
	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"

	linea='\e[38;5;17m#\e[39m  '; linea_no_esc='#  '
	for i in {0..27}; do
		if [[ $i -lt $mem_tamano ]]; then
			linea+="$(printf " %2d" "$i")"; linea_no_esc+="$(printf " %2d" "$i")"
		else
			linea+='   '; linea_no_esc+='   '
		fi
	done
	linea+='  \e[38;5;17m#\e[39m'; linea_no_esc+='  #'
	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"
	header 0

	linea='\e[38;5;17m#\e[39m  '; linea_no_esc='#  '
	for ((i=tiempo-36; i<tiempo; i++)); do
		if [[ $i -ge 0 ]] && [[ ${linea_tiempo[i]} -ne -1 ]]; then
			if [[ $i -gt 0 ]] && [[ ${linea_tiempo[i]} -eq ${linea_tiempo[((i-1))]} ]]; then
				((++ultimo_cambio))
			else
				ultimo_cambio=0
			fi
			if [[ $ultimo_cambio -eq 0 ]]; then
				linea+="\e[${proc_color[linea_tiempo[i]]}m| "; linea_no_esc+='| '
			elif [[ $((ultimo_cambio * 2 -2)) -lt ${#proc_id[linea_tiempo[i]]} ]]; then
				id=$(echo ${proc_id[linea_tiempo[i]]} | cut -c $(($ultimo_cambio * 2 - 1))-)
				linea_buffer=$(printf "%-2s" "${id:0:2}")
				linea+="\e[${proc_color[linea_tiempo[i]]}m$linea_buffer"; linea_no_esc+="$linea_buffer"
			else
				linea+='\e[0m  '; linea_no_esc+='  '
			fi
		else
			linea+='  '; linea_no_esc+='  '
		fi
	done
	linea+='\e[0m|    proceso  \e[38;5;17m#\e[39m'; linea_no_esc+='|    proceso  #'
	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"

	linea='\e[38;5;17m#\e[39m  '; linea_no_esc='#  '
	for ((i=tiempo-36; i<tiempo; i++)); do
		if [[ $i -ge 0 ]] && [[ ${linea_tiempo[i]} -ne -1 ]]; then
			linea+="\e[${proc_color[${linea_tiempo[$i]}]}m=="; linea_no_esc+='=='
		else
			linea+='\e[49;38;5;237m--'; linea_no_esc+='--'
		fi
	done
	linea+='\e[49;38;5;236m----------->\e[0m  \e[38;5;17m#\e[39m'; linea_no_esc+='----------->  #'
	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"

	ultimo_cambio=0
	linea='\e[38;5;17m#\e[39m  '; linea_no_esc='#  '
	for ((i=tiempo-36; i<tiempo; i++)); do
		if [[ $i -ge 0 ]] && [[ ${linea_tiempo[i]} -ne -1 ]]; then
			if [[ $i -gt 0 ]] && [[ ${linea_tiempo[i]} -eq ${linea_tiempo[((i-1))]} ]]; then
				((++ultimo_cambio))
			else
				ultimo_cambio=0
			fi
			if [[ $ultimo_cambio -eq 0 ]]; then
				linea+="\e[${proc_color[linea_tiempo[i]]}m| "; linea_no_esc+='| '
			elif [[ $((ultimo_cambio * 2 -2)) -lt ${#i} ]]; then
				id=$(echo $((i-1)) | cut -c $(($ultimo_cambio * 2 - 1))-)
				linea_buffer=$(printf "%-2s" "${id:0:2}")
				linea+="\e[${proc_color[linea_tiempo[i]]}m$linea_buffer"; linea_no_esc+="$linea_buffer"
			else
				linea+='\e[0m  '; linea_no_esc+='  '
			fi
		else
			linea+='  '; linea_no_esc+='  '
		fi
	done
	linea_buffer=$(printf "\e[0m| %-3s tiempo  " "$tiempo")
	linea+="$linea_buffer\e[38;5;17m#\e[39m"; linea_no_esc+="$linea_buffer#"
	pantalla "$linea"; log 3 "$linea" "$linea_no_esc"

	header 0
}

#######################################
#	Realiza un paso de tiempo
#	Globales:
#		evento
#		evento_log
#		evento_log_NoEsc
#		mem_proc_id
#		mem_tamano
#		mem_tamano_abreviacion
#		mem_tamano_redondeado
#		mem_usada
#		mem_usada_abreviacion
#		mem_usada_redondeado
#		modo_debug
#		modo_silencio
#		proc_count
#		proc_count_abreviacion
#		proc_count_redondeado
#		swp_proc_id
#		tiempo
#		tiempo_break
#		tiempo_final
#		tiempo_unbreak
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function step() {
	local -i i
	local tecla
	if [[ $tiempo -le $tiempo_final ]]; then poblarSwap; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then poblarMemoria; fi
	if [[ ${#mem_proc_id[@]} -eq 0 ]]; then
		if [[ ${#swp_proc_id[@]} -eq 0 ]] && [[ $tiempo -gt $tiempo_final ]]; then finalizarEjecucion 0; fi
		if [[ ${proc_tamano[${swp_proc_index[0]}]} -gt $mem_tamano ]]; then finalizarEjecucion 20; fi
		if [[ $tiempo -ge 0 ]]; then linea_tiempo[$tiempo]=-1; fi
	else
		calcularEjecucion
	fi

	if [[ -n $tiempo_break ]] && [[ $((tiempo + 1)) -eq $tiempo_break ]]; then
		modo_debug=1
		if [[ -n $modo_silencio ]]; then
			modo_silencio_break=1
			notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion" #abrevia la memoria
			notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
			notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"
			unset modo_silencio
		fi
	fi

	if [[ -n $tiempo_unbreak ]] && [[ $tiempo -eq $tiempo_unbreak ]]; then
		unset modo_debug
		if [[ -n $modo_silencio_break ]]; then
			modo_silencio=1
			unset modo_silencio_break
		fi
	fi

	if [[ -n $evento ]] || [[ -n $modo_debug ]]; then
		salidaEjecucion
	fi

	if [[ -n $evento ]]; then
		for ((i=0; i<${#evento_log[@]}; i++)); do
			log 5 "${evento_log[$i]}" "${evento_log_NoEsc[$i]}"
		done
		pantalla "${evento::-2}"
		evento_log=()
		evento_log_NoEsc=()
	fi

	if [[ -n $evento ]] || [[ -n $modo_debug ]]; then
		log 3
		if [[ -z $modo_silencio ]]; then
			read -p "Presiona cualquier tecla para continuar " -n 1 -r tecla
		fi
	fi
	unset evento

	if [[ ${#mem_proc_id[@]} -gt 0 ]]; then
		ejecucion
	fi

	((tiempo++))
}

#######################################
#	Abrevia número
#	Globales:
#		Nada
#	Argumentos:
#		global abreviacion
#		global redondeado
#		numero
#	Devuelve:
#		Nada
#######################################
function notacionCientifica() {
	local -ri numero=$1 #primer argumento es el numero a redondear
	local -rn redondeado="$2" abreviacion="$3" #la variable donde se guardara la aproximación y la variable donde se guarda la abreviacion
	local -i i=1000
	while [[ -z $redondeado ]]; do
		if [[ $numero -ge $i ]]; then
			i=$((i * 1000))
		else
			case "$i" in
			"1000")
				abreviacion=;;
			"1000000")
				abreviacion="K";;
			"1000000000")
				abreviacion="M";;
			"1000000000000")
				abreviacion="G";;
			"1000000000000000")
				abreviacion="T";;
			*)
				abreviacion="?";;
			esac
			redondeado=$((numero % i / (i / 1000)))
		fi
	done
}

#######################################
#	Mete procesos en swap
#	Globales:
#		evento
#		evento_log
#		evento_log_NoEsc
#		proc_color
#		proc_estado
#		proc_id
#		proc_tiempo_llegada
#		swp_proc_id
#		swp_proc_index
#		tiempo
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function poblarSwap() {
	local -i i
	for (( i=0 ; i<${#proc_id[@]}; i++ )); do
		if [[ ${proc_tiempo_llegada[$i]} -eq $tiempo ]]; then
			evento+="\e[${proc_color[$i]}m${proc_id[$i]}\e[0m > \e[93mespera\e[0m, "
			evento_log+=("\e[${proc_color[${i}]}m${proc_id[$i]}\e[0m entra en swap en instante \e[44m$tiempo")
			evento_log_NoEsc+=("${proc_id[$i]} entra en swap en instante <${tiempo}>")
			swp_proc_id+=("${proc_id[$i]}")
			swp_proc_index+=("$i")
			((proc_estado[i]|=2))
		fi
	done
}

#######################################
#	Mete procesos en memoria
#	Globales:
#		evento
#		evento_log
#		evento_log_NoEsc
#		mem_paginas
#		mem_paginas_secuencia
#		mem_proc_id
#		mem_proc_index
#		mem_proc_tamano
#		mem_tamano
#		mem_usada
#		mem_usada_abreviacion
#		mem_usada_redondeado
#		modo_silencio
#		proc_color
#		proc_estado
#		proc_tamano
#		swp_proc_id
#		swp_proc_index
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function poblarMemoria() {
	local -i espacio_valido=1 i j index
	local id
	mem_usada=${#mem_paginas[@]} #memoria usada es igual al numero de paginas
	if [[ -n $swp_proc_id ]]; then #si la swap no es nulo lo que pasara a continuacion te sorprendera...
		until [[ ${proc_tamano[${swp_proc_index[0]}]} -gt $((mem_tamano - mem_usada)) ]] || [[ ${#swp_proc_id[@]} -eq 0 ]] || [[ $espacio_valido -eq 0 ]]; do #mientras el tamaño del primer proceso en el swap sea mayor que la memoria libre o el numero de procesos del swap sea cero hacer...
			for ((i=0 ; i<=$((mem_tamano - proc_tamano[swp_proc_index[0]] )) ; i++ )); do #para i=0 hasta mayor que 500 menos el tamaño del primer proceso incrementar
				espacio_valido=1 #define variable local espacio valido igual a 1
				for ((j=0 ; j<proc_tamano[swp_proc_index[0]] ; j++ )); do #por cada tamaño del proceso
					if [[ -z ${mem_paginas[$(($i + $j))]} ]]; then #si la memoria es nula
						espacio_valido=$((espacio_valido * 1)) #entonces es valido
					else
						i=$((i + j)) #sino pasa al siguiente bloque de memoria
						espacio_valido=0
						break
					fi
				done
				if [[ $espacio_valido -eq 1 ]]; then #si el espacio es valido entonces
					index=${swp_proc_index[0]}
					id=${swp_proc_id[0]}
					evento+="\e[${proc_color[index]}m$id\e[0m > \e[92men memoria\e[0m, "
					evento_log+=("\e[${proc_color[index]}m$id\e[0m entra en memoria en instante \e[44m$tiempo\e[0m, despues de esperar \e[44m$((tiempo - proc_tiempo_llegada[swp_proc_index[0]]))\e[0m")
					evento_log_NoEsc+=("$id entra en memoria en instante <${tiempo}>, despues de esperar <$((tiempo - proc_tiempo_llegada[swp_proc_index[0]]))>")
					mem_proc_id+=("$id") #guarda la id
					mem_proc_index+=("$index") #guarda index
					mem_proc_tamano+=("${proc_tamano[index]}") #guarda tamaño
					((proc_estado[swp_proc_index[0]]|=4))
					mem_usada=$((mem_usada + proc_tamano[swp_proc_index[0]])) #y actualiza la memoria usada
					for ((j=0 ; j<proc_tamano[swp_proc_index[0]] ; j++ )); do #por cada tamaño del proceso
						mem_paginas[$((i + j))]=$index #guarda la index de cada proceso de memoria en el espacio correspondiente
						mem_paginas_secuencia[$((i + j))]=-1
					done
					actualizarPosiciones
					unset swp_proc_id[0] #saca el proceso del swap
					unset swp_proc_index[0]
					swp_proc_id=("${swp_proc_id[@]}") #limpia espacios vacios de la lista
					swp_proc_index=("${swp_proc_index[@]}")
					break
				fi
			done
		done
	fi
	if [[ -n $swp_proc_id ]] && [[ ${proc_tamano[${swp_proc_index[0]}]} -le $((mem_tamano - mem_usada)) ]]; then
		desfragmentarMemoria
		poblarMemoria
	fi
	if [[ -z $modo_silencio ]]; then
		unset mem_usada_redondeado
		notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
	fi
}

#######################################
#	Saca procesos de memoria
#	Globales:
#		evento
#		evento_log
#		evento_log_NoEsc
#		mem_paginas
#		mem_proc_id
#		mem_proc_index
#		mem_proc_tamano
#		mem_tamano
#		mem_usada
#		mem_usada_abreviacion
#		mem_usada_redondeado
#		modo_silencio
#		proc_color
#		proc_estado
#		proc_posicion
#		proc_tiempo_ejecucion
#		proc_tiempo_espera
#		proc_tiempo_salida
#	Argumentos:
#		Indice de proceso
#		Indice de memoria
#	Devuelve:
#		Nada
#######################################
function eliminarMemoria() {
	local -ri index_objetivo=$1 index_mem_objetivo=$2
	local -i i
	for (( i=0 ; i<mem_tamano ; i++ )); do
		if [[ -n ${mem_paginas[$i]} ]] && [[ ${mem_proc_index[$index_mem_objetivo]} -eq ${mem_paginas[$i]} ]]; then #si la id del proceso es igual a la id del que buscasa entonces...
			unset mem_paginas[$i] #saca procesos de la memoria si
		fi
	done
	i=0
	for index in ${mem_proc_index[@]}; do #por cada indice en memoria hacer...
		if [[ $index_objetivo -eq $index ]]; then #si lo encuentras entonces...
			evento+="\e[${proc_color[${mem_proc_index[$i]}]}m${mem_proc_id[$i]}\e[0m > \e[96mfinaliza\e[0m, "
			proc_tiempo_salida[$index]=$tiempo
			((proc_estado[index]|=16))
			evento_log+=("\e[${proc_color[${index}]}m${mem_proc_id[$i]}\e[0m termina en instante \e[44m$tiempo\e[0m, con tiempo de espera \e[44m${proc_tiempo_espera[$index]}\e[0m y tiempo de ejecución \e[44m${proc_tiempo_ejecucion[${index}]}")
			evento_log_NoEsc+=("${mem_proc_id[$i]} sale de memoria en <${tiempo}>, con tiempo de espera <${proc_tiempo_espera[$index]}> y tiempo de ejecución <${proc_tiempo_ejecucion[${index}]}>")
			unset mem_proc_index[$i] #saca el indice de memoria
			unset mem_proc_id[$i] #saca el id de memoria
			for pos in ${proc_posicion[$index]}; do #por cada posicion del proceso hacer...
				unset mem_paginas_secuencia[$pos] #saca las paginas
			done
			unset proc_posicion[$index]
			unset mem_proc_tamano[$i] #saca el proceso de tamaño de la memoria
			mem_proc_index=( "${mem_proc_index[@]}" ) #desfragmenta la lista
			mem_proc_id=( "${mem_proc_id[@]}" )
			mem_proc_tamano=( "${mem_proc_tamano[@]}" )
		fi
		((i++))
	done
	if [[ -z $modo_silencio ]]; then
		mem_usada=${#mem_paginas[@]}
		unset mem_usada_redondeado
		notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
	fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then poblarMemoria; fi
}

#######################################
#	Agrupa procesos en memoria
#	Globales:
#		evento
#		mem_paginas
#		mem_paginas_secuencia
#		mem_tamano
#		mem_usada
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function desfragmentarMemoria() {
	local -i i j
	until [[ $((pivot_final + 1)) -eq $mem_usada ]]; do
		local -i pivot=-1 pivot_final=0 count=0
		for ((i=(mem_tamano - 1) ; i>=0 ; i-- )); do
			if [[ -z ${mem_paginas[$i]} ]]; then
				if [[ $pivot -gt 0 ]]; then ((count++)); fi
			else
				if [[ $pivot -lt 0 ]]; then pivot_final=$i; fi
				pivot=$i
			fi
		done
		if [[ ! $((pivot_final + 1)) -eq $mem_usada ]]; then
			for ((j=0 ; j<=count ; j++ )); do # por cada hueco hace...
				for ((i=0 ; i<=pivot_final ; i++ )); do #por cada proceso comprueba si hay un hueco a la izquierda
					if [[ -z ${mem_paginas[$i]} ]] && [[ -n ${mem_paginas[$((i + 1))]} ]]; then #si hay hueco se mueve
						mem_paginas[$i]=${mem_paginas[$((i + 1))]}
						mem_paginas_secuencia[$i]=${mem_paginas_secuencia[$((i + 1))]}
						unset mem_paginas[$((i + 1))]
						unset mem_paginas_secuencia[$((i + 1))]
					fi
				done
			done
		fi
	done
	actualizarPosiciones
	evento+="\e[94mDESFRAGMENTACIÓN\e[0m, "
}

#######################################
#	Ejecuta un proceso en CPU
#	Globales:
#		linea_tiempo
#		mem_proc_index
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_restante
#		proc_tiempo_espera
#		proc_tiempo_respuesta
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function ejecucion() {
	local -i i
	for index in ${mem_proc_index[@]}; do
		((++proc_tiempo_respuesta[index]))
		if (((proc_estado[index]&8)==8)); then
			((--proc_tiempo_ejecucion_restante[index]))
			((++proc_tiempo_ejecucion[index]))
			linea_tiempo[$tiempo]=$index
			if [[ ${proc_tiempo_ejecucion_restante[$index]} -eq 0 ]]; then
				eliminarMemoria $index $i
			else
				actualizarPaginas $index
			fi
		else
			((++proc_tiempo_espera[index]))
		fi
		((i++))
	done
	for index in ${swp_proc_index[@]}; do
		((++proc_tiempo_espera[index]))
		((++proc_tiempo_respuesta[index]))
	done
}

#######################################
#	SRPT de procesos en memoria
#	Globales:
#		mem_proc_index
#		mem_siguiente_ejecucion
#		proc_estado
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_restante
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function calcularEjecucion() {
	local -i min=${proc_tiempo_ejecucion_restante[${mem_proc_index[0]}]} min_index=${mem_proc_index[0]}
	for index in ${mem_proc_index[@]}; do #por cada indice de la memoria hacer...
		if [[ ${proc_tiempo_ejecucion_restante[$index]} -lt $min ]]; then #si el tiempo de ejecucion es el menor
			min=${proc_tiempo_ejecucion_restante[$index]} #guardalo como nuevo minimo
			min_index=$index
		fi
		((proc_estado[index]&=~8))
	done
	((proc_estado[min_index]|=8))
}

#######################################
#	Ordena los proc. por orden de llegada
#	Globales:
#		proc_orden
#		proc_tiempo_llegada
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function ordenarProcesos() {
	local -i i j min_index=0 min=${proc_tiempo_llegada[0]}
	local -a procesos_pendientes
	procesos_pendientes=("${proc_tiempo_llegada[@]}")
	for ((i=0; i<proc_count; i++)); do
		for ((j=0; j<${#procesos_pendientes[@]}; j++)); do
			if [[ ${procesos_pendientes[j]} -lt $min && ${procesos_pendientes[j]} -ge 0 ]] || [[ $min -eq -1 ]]; then
				min=${procesos_pendientes[j]}
				min_index=$j
			fi
		done
		proc_orden[$i]=$min_index
		procesos_pendientes[$min_index]=-1
		min=-1
	done
}

#######################################
#	Realiza sustitución de páginas
#	Globales:
#		mem_paginas_secuencia
#		proc_tamano
#		proc_posicion
#		proc_paginas_apuntador
#		proc_paginas_fallos
#		proc_paginas
#	Argumentos:
#		Index de proceso
#	Devuelve:
#		Nada
#######################################
function actualizarPaginas() {
	local -ri index=$1
	local -i fallo
	local -a paginas=()
	IFS=',' read -r -a paginas <<< "${proc_paginas[index]}"
	local -r objetivo=${paginas[$((proc_tiempo_ejecucion[index]-1))]}
	for posicion in ${proc_posicion[index]}; do
		if [[ ${mem_paginas_secuencia[posicion]} -eq $objetivo ]]; then fallo=1; fi
	done
	if [[ -z $fallo ]]; then
		mem_paginas_secuencia[$(( $(echo ${proc_posicion[index]} | cut -d ' ' -f1) + proc_paginas_apuntador[index] ))]=$objetivo
		proc_paginas_apuntador[index]=$((++proc_paginas_apuntador[index]%proc_tamano[index]))
		((++proc_paginas_fallos[index]))
	fi
}

#######################################
#	Localiza cada proceso en memoria
#	Globales:
#		mem_paginas
#		mem_proc_index
#		mem_tamano
#		proc_posicion
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function actualizarPosiciones() {
	local -i p i
	for ((p=0; p<${#mem_proc_index[@]}; p++ )) ; do
		local -a posiciones=()
		local -i inx=${mem_proc_index[p]}
		for ((i=0; i<mem_tamano; i++ )); do
			if [[ ${mem_paginas[i]} -eq $inx ]] && [[ -n ${mem_paginas[i]} ]]; then
				posiciones+=("$i")
			fi
		done
		proc_posicion[$inx]=${posiciones[@]}
	done
}

#######################################
#	Calcula última llegada de proceso
#	Globales:
#		proc_tiempo_llegada
#	Argumentos:
#		Nada
#	Devuelve:
#		Último tiempo
#######################################
function ultimoTiempo() {
	local -i tiempo_max=0
	for t in "${proc_tiempo_llegada[@]}"; do
		if [[ $t -gt $tiempo_max ]]; then tiempo_max=$t; fi #coge el tiempo de llegada maximo de todos los tiempos
	done
	echo $tiempo_max
}

#######################################
#	Calcula última llegada de proceso
#	Globales:
#		date
#		linea_tiempo
#		proc_color
#		proc_id
#		proc_paginas_fallos
#		proc_tiempo_ejecucion
#		proc_tiempo_espera
#		proc_tiempo_espera
#		proc_tiempo_llegada
#		proc_tiempo_respuesta
#		proc_tiempo_salida
#		SECONDS
#		tiempo
#	Argumentos:
#		Código de error
#	Devuelve:
#		Nada
#######################################
function finalizarEjecucion() {
	local -ri error=$1
	local -i i j espera_total=0 respuesta_total=0 fallos_total=0 ultimo_cambio buffer_1=0 buffer_2=0
	local id linea linea_no_esc linea_buffer
	if [[ $error -eq 0 ]]; then
		salidaEjecucion
		pantalla
		log 5
		linea="$(printf "%7s%s%8s-  %s  -  %s  -  %s  -  %s  -  %s" " " "ID" " " "LLEGADA" "SALIDA" "REPUESTA" "ESPERA" "FALLOS")"
		log 5 "$linea" '@'
		pantalla "$linea"
		for ((i=0; i<proc_count; i++)); do
			id=${proc_id[i]:0:15}
			linea="$(printf "\e[%sm%*s\e[0m%*s - %5d     -  %5d   -  %5d     - %5d    - %5d" "${proc_color[i]}" "$(((${#id}+16)/2))" "$id" "$((8-${#id}/2))" " " "${proc_tiempo_llegada[i]}" "${proc_tiempo_salida[i]}" "${proc_tiempo_respuesta[i]}" "${proc_tiempo_espera[i]}" "${proc_paginas_fallos[i]}")"
			linea_no_esc="$(printf "%*s%*s - %5d     -  %5d   -  %5d     - %5d    - %5d" "$(((${#id}+16)/2))" "$id" "$((8-${#id}/2))" " " "${proc_tiempo_llegada[i]}" "${proc_tiempo_salida[i]}" "${proc_tiempo_respuesta[i]}" "${proc_tiempo_espera[i]}" "${proc_paginas_fallos[i]}")"
			log 5 "$linea" "$linea_no_esc"
			pantalla "$linea"
			espera_total+=${proc_tiempo_espera[i]}
			respuesta_total+=${proc_tiempo_respuesta[i]}
			fallos_total+=${proc_paginas_fallos[i]}
		done
		linea=;linea_no_esc=
		pantalla
		log 5

		for ((j=0; j< (tiempo+39)/40; j++)); do
			ultimo_cambio=$buffer_1
			for ((i=j*40; i<=j*40+40 && i<tiempo; i++)); do
				if [[ $i -ge 0 ]] && [[ ${linea_tiempo[i]} -ne -1 ]]; then
					if [[ $i -gt 0 ]] && [[ ${linea_tiempo[i]} -eq ${linea_tiempo[((i-1))]} ]]; then
						((++ultimo_cambio))
					else
						ultimo_cambio=0
					fi
					if [[ $ultimo_cambio -eq 0 ]]; then
						linea+="\e[${proc_color[linea_tiempo[i]]}m| "; linea_no_esc+='| '
					elif [[ $((ultimo_cambio * 2 -2)) -lt ${#proc_id[linea_tiempo[i]]} ]]; then
						id=$(echo ${proc_id[linea_tiempo[i]]} | cut -c $(($ultimo_cambio * 2 - 1))-)
						linea+="$(printf "%-2s" "${id:0:2}")"; linea_no_esc+="$(printf "%-2s" "${id:0:2}")"
					else
						linea+='\e[0m  '; linea_no_esc+='  '
					fi
				else
					linea+='\e[0m  '; linea_no_esc+='  '
				fi
			done
			log 3 "$linea" "$linea_no_esc"; linea=''; linea_no_esc=''
			buffer_1=$ultimo_cambio

			for ((i=j*40; i<=j*40+40 && i<tiempo; i++)); do
				if [[ $i -ge 0 ]] && [[ ${linea_tiempo[i]} -ne -1 ]]; then
					linea+="\e[${proc_color[${linea_tiempo[$i]}]}m=="; linea_no_esc+='=='
				else
					linea+='\e[49;38;5;237m--'; linea_no_esc+='--'
				fi
			done
			log 3 "$linea" "$linea_no_esc"; linea=''; linea_no_esc=''

			ultimo_cambio=$buffer_2
			for ((i=j*40; i<=j*40+40 && i<tiempo; i++)); do
				if [[ $i -ge 0 ]] && [[ ${linea_tiempo[i]} -ne -1 ]]; then
					if [[ $i -gt 0 ]] && [[ ${linea_tiempo[i]} -eq ${linea_tiempo[((i-1))]} ]]; then
						((++ultimo_cambio))
					else
						ultimo_cambio=0
					fi
					if [[ $ultimo_cambio -eq 0 ]]; then
						linea+="\e[${proc_color[linea_tiempo[i]]}m| "; linea_no_esc+='| '
					elif [[ $((ultimo_cambio * 2 -2)) -lt ${#i} ]]; then
						id=$(echo $((i-1)) | cut -c $(($ultimo_cambio * 2 - 1))-)
						linea+="$(printf "%-2s" "${id:0:2}")"; linea_no_esc+="$(printf "%-2s" "${id:0:2}")"
					else
						linea+='\e[0m  '; linea_no_esc+='  '
					fi
				else
					linea+='  '; linea_no_esc+='  '
				fi
			done
			log 3 "$linea" "$linea_no_esc"; linea=''; linea_no_esc=''
			buffer_2=$ultimo_cambio
			log 3
		done

		linea_buffer="$((espera_total / proc_count)).$(( (espera_total * 1000 ) / proc_count % 1000))"
		linea="Tiempo de espera medio: \e[44m$linea_buffer"
		linea_no_esc="Tiempo de espera medio: <$linea_buffer>"
		pantalla "$linea"; log 5 "$linea" "$linea_no_esc"
		linea_buffer="$((respuesta_total / proc_count)).$(( (respuesta_total * 1000 ) / proc_count % 1000))"
		linea="Tiempo de respuesta medio: \e[44m$linea_buffer"
		linea_no_esc="Tiempo de respuesta medio: <$linea_buffer>"
		pantalla "$linea"; log 5 "$linea" "$linea_no_esc"
		linea_buffer="$((fallos_total / proc_count)).$(( (fallos_total * 1000 ) / proc_count % 1000))"
		linea="Numero de fallos medio: \e[44m$linea_buffer"
		linea_no_esc="Numero de fallos medio: <$linea_buffer>"
		pantalla "$linea"; log 5 "$linea" "$linea_no_esc"
		log 5
		log 0 "TIEMPO DE EJECUCIÓN: \e[44m${SECONDS}s" "TIEMPO DE EJECUCIÓN: <${SECONDS}s>"
		log 5 "ÚLTIMO TIEMPO: \e[44m$tiempo" "ÚLTIMO TIEMPO: <$tiempo>"
		pantalla "\nFINAL DE EJECUCIÓN - ÚLTIMO TIEMPO: \e[44m$tiempo\e[0m"
		log 9 "FINAL DE EJECUCIÓN CON FECHA \e[44m$(date)\e[49m" "FINAL DE EJECUCIÓN CON FECHA <$(date)>"
	else
		pantalla "\e[91m!!!\e[39m EXCEPCIÓN \e[91m${error}\e[39m \e[91m!!!\e[39m"
		log 9 "\e[91m!!!\e[39m EXCEPCIÓN \e[91m${error}\e[39m CON FECHA \e[44m$(date)\e[49m \e[91m!!!\e[39m" "!!! EXCEPCIÓN <${error}> CON FECHA <$(date)> !!!"
	fi
	header 0 2
	exit $error
}

#######################################
#	Escribe en ficheros de salida
#	Globales:
#		nivel_log
#	Argumentos:
#		Nível
#		Mensaje con escapes:
#			NULL = Linea vacia
#		Mensaje sin escapes:
#			NULL = Linea vacia
#			@ = Mismo mensaje que con esc.
#	Devuelve:
#		Nada
#######################################
function log() {
	local -ri nivel=$1
	local -r mensaje=$2 mensaje_noesc=$3
	if [[ $nivel -ge $nivel_log ]]; then
		if [[ -n $mensaje ]]; then
			echo -e "[$(colorLog $nivel)${nivel}\e[39m] > ${mensaje}\e[0m" >> salida.txt
		else
			echo >> salida.txt
		fi
		if [[ -n $mensaje_noesc ]]; then
			if [[ $mensaje_noesc == '@' ]]; then
				echo "[${nivel}] > ${mensaje}" >> salidaNoEsc.txt
			else
				echo "[${nivel}] > ${mensaje_noesc}" >> salidaNoEsc.txt
			fi
		else
			echo >> salidaNoEsc.txt
		fi
	fi
}

#######################################
#	Escribe en pantalla
#	Globales:
#		modo_silencio
#	Argumentos:
#		Mensaje con escapes
#	Devuelve:
#		Nada
#######################################
function pantalla() {
	local -r mensaje=$1
	if [[ -z $modo_silencio ]]; then
		echo -e "$mensaje\e[0m"
	fi
}

#######################################
#	Escribe datos en el archivo de salida
#	Globales:
#		mem_tamano
#		proc_color
#		proc_count
#		proc_id
#		proc_pagina_tamano
#		proc_paginas
#		proc_tamano
#		proc_tiempo_llegada
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function salidaDatos() {
	local -i i
	local colores=$(for color in ${proc_color[@]}; do echo -n "$(echo $color | cut -d ';' -f6),$(echo $color | cut -d ';' -f3) ; "; done)
	echo "+MEMORIA: $mem_tamano" > salidaEntrada.txt
	echo "+DIRECCIONES: $proc_pagina_tamano" >> salidaEntrada.txt
	echo "+COLORES: ${colores::-2}" >> salidaEntrada.txt
	for ((i=0; i<proc_count; i++)); do
		echo "${proc_tamano[i]} ; ${proc_direcciones[i]} ; ${proc_tiempo_llegada[i]} ; ${proc_id[i]}" >> salidaEntrada.txt
	done
}

#######################################
#	Selecciona color del nivel de log
#	Globales:
#		Nada
#	Argumentos:
#		Nível
#	Devuelve:
#		Color
#######################################
function colorLog() {
	local -ri nivel=$1
	case $nivel in
		1) echo -e "\e[35m";;
		2) echo -e "\e[34m";;
		3) echo -e "\e[36m";;
		4) echo -e "\e[91m";;
		5) echo -e "\e[33m";;
		9) echo -e "\e[32m";;
		*) echo -e "\e[39m";;
	esac
}

#######################################
#	Escribe cabecera de fichero
#	Globales:
#		nivel_log
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function cabeceraLog() {
	if [[ $nivel_log -le 1 ]]; then
		log 1 'LICENCIA DE USO:' '@'
		header 0 2
		log 1 "\e[38;5;17m#\e[39m$(printf "%88s" " ")\e[38;5;17m#\e[39m" "#$(printf "%88s" " ")#"
		log 1 "\e[38;5;17m#\e[39m                                      MIT License                                       \e[38;5;17m#\e[39m" "#                                      MIT License                                       #"
		log 1 "\e[38;5;17m#\e[39m                     Copyright (c) 2017 Diego González, Rodrigo Díaz                    \e[38;5;17m#\e[39m" "#                     Copyright (c) 2017 Diego González, Rodrigo Díaz                    #"
		log 1 "\e[38;5;17m#\e[39m                 ――――――――――――――――――――――――――――――――――――――――――――――――――――――                 \e[38;5;17m#\e[39m" "#                 ――――――――――――――――――――――――――――――――――――――――――――――――――――――                 #"
		log 1 "\e[38;5;17m#\e[39m              You may:                                                                  \e[38;5;17m#\e[39m" "#              You may:                                                                  #"
		log 1 "\e[38;5;17m#\e[39m                - Use the work commercially                                             \e[38;5;17m#\e[39m" "#                - Use the work commercially                                             #"
		log 1 "\e[38;5;17m#\e[39m                - Make changes to the work                                              \e[38;5;17m#\e[39m" "#                - Make changes to the work                                              #"
		log 1 "\e[38;5;17m#\e[39m                - Distribute the compiled code and/or source.                           \e[38;5;17m#\e[39m" "#                - Distribute the compiled code and/or source.                           #"
		log 1 "\e[38;5;17m#\e[39m                - Incorporate the work into something that                              \e[38;5;17m#\e[39m" "#                - Incorporate the work into something that                              #"
		log 1 "\e[38;5;17m#\e[39m                  has a more restrictive license.                                       \e[38;5;17m#\e[39m" "#                  has a more restrictive license.                                       #"
		log 1 "\e[38;5;17m#\e[39m                - Use the work for private use                                          \e[38;5;17m#\e[39m" "#                - Use the work for private use                                          #"
		log 1 "\e[38;5;17m#\e[39m$(printf "%88s" " ")\e[38;5;17m#\e[39m" "#$(printf "%88s" " ")#"
		log 1 "\e[38;5;17m#\e[39m              You must:                                                                 \e[38;5;17m#\e[39m" "#              You must:                                                                 #"
		log 1 "\e[38;5;17m#\e[39m                - Include the copyright notice in all                                   \e[38;5;17m#\e[39m" "#                - Include the copyright notice in all                                   #"
		log 1 "\e[38;5;17m#\e[39m                  copies or substantial uses of the work                                \e[38;5;17m#\e[39m" "#                  copies or substantial uses of the work                                #"
		log 1 "\e[38;5;17m#\e[39m                - Include the license notice in all copies                              \e[38;5;17m#\e[39m" "#                - Include the license notice in all copies                              #"
		log 1 "\e[38;5;17m#\e[39m                  or substantial uses of the work                                       \e[38;5;17m#\e[39m" "#                  or substantial uses of the work                                       #"
		log 1 "\e[38;5;17m#\e[39m$(printf "%88s" " ")\e[38;5;17m#\e[39m" "#$(printf "%88s" " ")#"
		log 1 "\e[38;5;17m#\e[39m              You cannot:                                                               \e[38;5;17m#\e[39m" "#              You cannot:                                                               #"
		log 1 "\e[38;5;17m#\e[39m                - Hold the author liable. The work is                                   \e[38;5;17m#\e[39m" "#                - Hold the author liable. The work is                                   #"
		log 1 "\e[38;5;17m#\e[39m                  provided \"as is\".                                                     \e[38;5;17m#\e[39m" "#                  provided \"as is\".                                                     #"
		log 1 "\e[38;5;17m#\e[39m$(printf "%88s" " ")\e[38;5;17m#\e[39m" "#$(printf "%88s" " ")#"
		header 0 2
		log 1
	fi
	if [[ $nivel_log -le 3 ]]; then
		log 1 'CABECERA DEL PROGRAMA:' '@'
		header 0 2
		log 3 "\e[38;5;17m#\e[39m$(printf "%88s" " ")\e[38;5;17m#\e[39m" "#$(printf "%88s" " ")#"
		log 3 "\e[38;5;17m#\e[39m                        \e[48;5;17mSRPT, Paginación, FIFO, Memoria Continua,\e[0m                       \e[38;5;17m#" "#                        SRPT, Paginación, FIFO, Memoria Continua,                       #"
		log 3 "\e[38;5;17m#\e[39m                       \e[48;5;17mFijas e iguales, Primer ajuste y Reubicable\e[0m                      \e[38;5;17m#" "#                       Fijas e iguales, Primer ajuste y Reubicable                      #"
		log 3 "\e[38;5;17m#\e[38;5;20m                 ――――――――――――――――――――――――――――――――――――――――――――――――――――――                 \e[38;5;17m#" "#                 ――――――――――――――――――――――――――――――――――――――――――――――――――――――                 #"
		log 3 "\e[38;5;17m#\e[96m                Alumnos:                                                                \e[38;5;17m#" "#                Alumnos:                                                                #"
		log 3 "\e[38;5;17m#\e[96m                  - González Román, Diego                                               \e[38;5;17m#" "#                  - González Román, Diego                                               #"
		log 3 "\e[38;5;17m#\e[96m                  - Díaz García, Rodrigo                                                \e[38;5;17m#" "#                  - Díaz García, Rodrigo                                                #"
		log 3 "\e[38;5;17m#\e[96m                Sistemas Operativos, Universidad de Burgos                              \e[38;5;17m#" "#                Sistemas Operativos, Universidad de Burgos                              #"
		log 3 "\e[38;5;17m#\e[96m                Grado en ingeniería informática (2016-2017)                             \e[38;5;17m#" "#                Grado en ingeniería informática (2016-2017)                             #"
		log 3 "\e[38;5;17m#\e[39m$(printf "%88s" " ")\e[38;5;17m#\e[39m" "#$(printf "%88s" " ")#"
		header 0 2
		log 3
	fi
}

#_____________________________________________
# FINAL DE FUNCIONES
#
# COMIENZO DE PROGRAMA PRINCIPAL
#_____________________________________________

SECONDS=0
declare -a proc_id proc_estado proc_tamano proc_paginas proc_direcciones proc_tiempo_llegada proc_tiempo_salida proc_tiempo_ejecucion proc_tiempo_ejecucion_restante proc_tiempo_espera proc_tiempo_respuesta proc_posicion proc_paginas_apuntador proc_paginas_fallos proc_orden mem_paginas mem_proc_id mem_proc_index mem_proc_tamano swp_proc_id swp_proc_index out_proc_index proc_color_secuencia linea_tiempo
declare -i proc_count mem_tamano mem_usada tiempo mem_tamano_redondeado mem_usada_redondeado proc_count_redondeado nivel_log=3
declare mem_tamano_abreviacion mem_usada_abreviacion proc_count_abreviacion evento evento_log evento_log_NoEsc filename

log 9
log 9 "EJECUCIÓN DE \e[44m${0}\e[49m EN \e[44m$(hostname)\e[49m CON FECHA \e[44m$(date)\e[49m" "EJECUCIÓN DE <${0}> EN <$(hostname)> CON FECHA <$(date)>"
log 9

if [[ $# -gt 0 ]]; then
	log 5 'Argumentos introducidos, obteniendo información:' '@'
	leerArgs "$@"
fi

cabeceraLog
header 1 1; header 0 1
if [[ -z $filename ]]; then #si no hay argumento de archivo entonces...
	log 5 'No Argumento filename, comprobando modo de introduccion de datos:' '@'
	read -p 'Introducción de datos por archivo (s/n): ' -n 1 -r ; echo
	log 0 "RESPUESTA INPUT: \e[34m$REPLY\e[39m" "RESPUESTA INPUT: <$REPLY>"
	if [[ $REPLY =~ ^[SsYy]$ ]]; then #si la respuesta es S
		read -p 'Nombre del archivo: ' filename
		log 5 "Por archivo \e[34m${filename}\e[39m" "Por archivo <${filename}>"
		leerArchivo
	else log 5 'Por teclado' '@';	fi
fi

pedirDatos
salidaDatos
ordenarProcesos

notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion"
notacionCientifica "$mem_usada" "mem_usada_redondeado" "mem_usada_abreviacion"
notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"

while true ; do step ; done
