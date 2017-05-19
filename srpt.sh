#! /bin/bash
#
# Simula la ejeución de una serie de procesos en un algoritmo SRPT
# AUTHOR: Rodrigo Díaz, Diego Gonzalez
# LICENSE: MIT

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
#		proc_count
#		proc_count_abreviacion
#		proc_count_redondeado
#		tiempo
#	Argumentos:
#		modo:
#			0 = linea separación
#			1 = cabecera principal
#			2 = cabecera secundaria
#	Devuelve:
#   Texto
#######################################
function header() {
	local -ri modo=$1
	if [ $modo -eq 0 ]; then
		for i in {17..21} {21..17} ; do echo -en "\e[38;5;${i}m########" ; done ; echo -e "\e[0m"
	elif [ $modo -eq 1 ]; then
		clear && clear
		header 0
		echo -e "\e[38;5;17m#\e[0m\e[48;5;17mSRPT, PAGINACIÓN FIFO, MEMORIA CONT, PARTES FIJAS IGUAL, 1er AJUSTE REUBICABLE\e[0m\e[38;5;17m#"
	else
		header 1
		printf "\e[38;5;17m#\e[0m      \e[48;5;17mMemoria: "
		if [[ -z $mem_usada_abreviacion ]]; then
			printf " %3d/" "$mem_usada_redondeado"
		else
			printf "%3d%1s/" "$mem_usada_redondeado" "$mem_usada_abreviacion"
		fi

		if [[ -z $mem_tamano_abreviacion ]]; then
			printf "%3d\e[0m " "$mem_tamano_redondeado"
		else
			printf "%3d%1s\e[0m" "$mem_tamano_redondeado" "$mem_tamano_abreviacion"
		fi
		printf "       \e[48;5;17mTiempo: %3d\e[0m      \e[48;5;17mNúmero de Procesos: " "$tiempo"
		if [[ -z $proc_count_abreviacion ]]; then
			printf " %3d" "$proc_count_redondeado"
		else
			printf "%3d%1s" "$proc_count_redondeado" "$proc_count_abreviacion"
		fi
		printf "\e[0m      \e[38;5;17m#\n"
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
#		proc_id
#		proc_pagina_tamano
#		proc_paginas
#		proc_tamano
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_restante
#		proc_tiempo_llegada
#		tiempo_final
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function pedirDatos() {
	if [ -z "$mem_tamano" ]; then #si el tamaño de memoria nulo
		until [[ $mem_tamano =~ ^[0-9]+$ ]] && [[ ! $mem_tamano -eq 0 ]]; do #hasta el tamaño de memoria empiece entre 0 y 9 Y sea diferente a 0 hacer...
			printf "\e[1A%80s\r" " " #imprimir 80 espacios en color 1A
			read -p "Tamaño (en bloques) de la memoria: " mem_tamano #te pide que escribas algo y eso eso va a ser el tamaño de memoria
			printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r" #te muestra en pantalla el texto y vuelve a la linea anterior
		done
		printf "%80s\n" " "
	fi

	if [ -z "$proc_pagina_tamano" ]; then
		until [[ $proc_pagina_tamano =~ ^[0-9]+$ ]] && [[ ! $proc_pagina_tamano -eq 0 ]]; do
			printf "\e[1A%80s\r" " "
			read -p "Direcciones por página: " proc_pagina_tamano
			printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
		done
		printf "%80s\n" " "
	fi

	if [ -z "$proc_count" ]; then
		until [[ $proc_count =~ ^[0-9]+$ ]] && [[ ! $proc_count -eq 0 ]]; do
			printf "\e[1A%80s\r" " "
			read -p "Número de procesos: " proc_count
			printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
		done
		printf "%80s\n" " "
	fi

	if [ -z "$proc_id" ]; then
		for i in $(seq 0 $(expr $proc_count - 1 )); do
			until [[ ${proc_tamano[$i]} =~ ^[0-9]+$ ]] && [[ ! ${proc_tamano[$i]} -eq 0 ]]; do
				printf "\e[1A%80s\r" " "
				read -p "[P${i}] Bloques en memoria: " proc_tamano[$i]
				printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
			done
			printf "%80s\n" " "

			until [[ ${proc_tiempo_llegada[$i]} =~ ^[0-9]+$ ]]; do
				printf "\e[1A%80s\r" " "
				read -p "[P${i}] Tiempo de llegada: " proc_tiempo_llegada[$i]
				printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
			done
			printf "%80s\n" " "

			printf "\e[1A%80s\r" " "
			read -p "[P${i}] Secuencia de direcciones: " proc_paginas[$i]
			echo

			proc_paginas[$i]=$(convertirDireccion ${proc_paginas[$i]})
			proc_id[$i]="P${i}" #Si no tiene la id asignada le da una
			if [[ $i -lt ${#proc_color_secuencia[@]} ]]; then
				proc_color[$i]="48;5;$(echo ${proc_color_secuencia[$i]} | cut -d ',' -f2);38;5;$(echo ${proc_color_secuencia[$i]} | cut -d ',' -f1)"
			else
				proc_color[$i]="48;5;$(shuf -i 0-256 -n 1);38;5;$(shuf -i 0-256 -n 1)"
			fi
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w) #Asigna el tiempo rastante al numero de paginas
			log 3 "Proceso \e[44m${i}\e[49m, con ID \e[44m${proc_id[$i]}\e[49m, Secuencia \e[44m${proc_paginas[$i]}\e[49m, Bloques \e[44m${proc_tamano[$i]}\e[49m, Llegada \e[44m${proc_tiempo_llegada[$i]}" "Proceso <${i}>, con ID <${proc_id[$i]}>, Secuencia <${proc_paginas[$i]}>, Bloques <${proc_tamano[$i]}>, Llegada <${proc_tiempo_llegada[$i]}>"
		done
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
#		-m	BLOQUES
#			Tamaño de memoria en bloques
#		-p	NÚMERO
#			Número de procesos
#		-s
#			Deshabilita salida por pantalla
#		-u TIEMPO
#			Deshabilita modo debug en TIEMPO
#	Devuelve:
#		Nada
#######################################
function leerArgs() {
	while [ "$1" != "" ]; do #mientras el parametro 1 no sea un espacio hacer
		case $1 in
			-s|--silencio) #si el parametro es s o silencio
				modo_silencio=1
				log 3 'Salida gráfica deshabilitada' '@';;
			-d|--debug)
				modo_debug=1
				nivel_log=0
				log 3 'Entrando modo debug' '@';;
			-f|--filename)
			  if [ -n "$2" ] && [[ ! $2 == -* ]]; then
					filename="$2"
					log 5 "Argumento de archivo introducido \e[44m$filename" "Argumento de archivo introducido <${filename}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--filename" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mfilename\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento filename contiene errores !!!'
					finalizarEjecucion 40
			  fi;;
			-m|--memoria)
			  if [ -n "$2" ] && [[ ! $2 == -* ]]; then
					local -ri tmp_mem_tamano="$2"
					log 5 "Argumento de memoria introducido \e[44m$tmp_mem_tamano" "Argumento de memoria introducido ${tmp_mem_tamano}"
					shift 2
					continue
			  else
					echo 'ERROR: "--memoria" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mmemoria\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento memoria contiene errores !!!'
					finalizarEjecucion 41
			  fi;;
			-p|--procesos)
			  if [ -n "$2" ] && [[ ! $2 == -* ]]; then
					proc_count="$2"
					log 5 "Argumento de procesos introducido \e[44m$proc_count" "Argumento de procesos introducido <${proc_count}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--procesos" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mprocesos\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento procesos contiene errores !!!'
					finalizarEjecucion 42
			  fi;;
			-l|--log)
			  if [ -n "$2" ] && [[ ! $2 == -* ]]; then
					nivel_log="$2"
				  log 5 "Establecido nivel de log a \e[44m$nivel_log" "Establecido nivel de log a <${nivel_log}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--log" requiere un argumento válido/no vacio.'
					log 9 '\e[91m!!!\e[39m El argumento \e[91mlog\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento log contiene errores !!!'
					finalizarEjecucion 43
			  fi;;
				-b|--breakpoint)
					if [ -n "$2" ] && [[ ! $2 == -* ]]; then
						tiempo_break="$2"
						log 9 "Estableciendo breakpoint en \e[44m$tiempo_break" "Estableciendo breakpoint en <${tiempo_break}>"
						shift 2
						continue
				  else
						echo 'ERROR: "--breakpoint" requiere un argumento válido/no vacio.'
						log 9 '\e[91m!!!\e[39m El argumento \e[91mbreakpoint\e[39m contiene errores \e[91m!!!\e[39m' '!!! El argumento breakpoint contiene errores !!!'
						finalizarEjecucion 44
				  fi;;
				-u|--unbreakpoint)
					if [ -n "$2" ] && [[ ! $2 == -* ]]; then
						tiempo_unbreak="$2"
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
	if [ ! -z "$filename" ]; then
		log 3 "Leyendo archivo:" '@'
		leerArchivo
		log 0 "Fin Lectura archivo" '@'
	fi
	if [ ! -z "$tmp_mem_tamano" ]; then
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
#		proc_id
#		proc_pagina_tamano
#		proc_paginas
#		proc_tamano
#		proc_tiempo_ejecucion
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
	if [ ! -f $filename ]; then
		echo "Archivo \"${filename}\" no válido."
		log 9 '\e[91m!!!\e[39m El archivo no existe \e[91m!!!\e[39m' '!!! El archivo no existe !!!'
		finalizarEjecucion 30
	fi
	IFS=$'\n'; set -f #Establece el valor de separacion como final de linea
	for line in $(<$filename); do
		line=$(echo $line | cut -d '#' -f1 | tr -d ' ' | tr -d '\r') #elimina los espacios (-d) y tr sustituye
		log 0 "Linea leida \e[44m$line" "Linea leida <${line}>"
		if [[ ! $line == +* ]] && [[ ! -z $line ]]; then #si la linea no empieza por # y + o no es nula entonces...
			proc_tamano[$i]=$(echo $line | cut -d ';' -f1) #guarda el tamaño, porque va cortando todolo separado por ; y coge la 1ª columna(-f1)
			proc_paginas[$i]=$(echo $line | cut -d ';' -f2) #guarda las paginas
			proc_tiempo_llegada[$i]=$(echo $line | cut -d';' -f3) #guarda el tiempo de llegada
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
			proc_paginas[$i]=$(convertirDireccion ${proc_paginas[$i]})
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w) #cuenta el numero de paginas y lo asigna al tiempo de ejecucion  restante
			log 3 "Proceso \e[44m${i}\e[49m, con ID \e[44m${proc_id[$i]}\e[49m, Secuencia \e[44m${proc_paginas[$i]}\e[49m, Bloques \e[44m${proc_tamano[$i]}\e[49m, Llegada \e[44m${proc_tiempo_llegada[$i]}\e[49m" "Proceso <${i}>, con ID <${proc_id[$i]}>, Secuencia <${proc_paginas[$i]}>, Bloques <${proc_tamano[$i]}>, Llegada <${proc_tiempo_llegada[$i]}>"
			((i++))
		else
			if [[ $line == +* ]]; then
				log 0 'Es opción:' '@'
				case $(echo $line | tr -d '+' | cut -d ':' -f1) in
					"MEMORIA")
						mem_tamano=$(echo $line | cut -d ':' -f2)
						log 0 "de memoria \e[44m$mem_tamano" "de memoria <${mem_tamano}>"
						log 3 "Configuración, bloques de memoria \e[44m$mem_tamano" "Configuración, bloques de memoria <${mem_tamano}>";;
					"DIRECCIONES")
						proc_pagina_tamano=$(echo $line | cut -d ':' -f2)
						log 0 "de página \e[44m$proc_pagina_tamano" "de página <${proc_pagina_tamano}>"
						log 3 "Configuración, tamaño de pagina \e[44m$proc_pagina_tamano" "Configuración, tamaño de pagina <${proc_pagina_tamano}>";;
					*)
						echo 'CONFIGURACIÓN EN FICHERO NO VÁLIDA'
						log 9 "\e[91m!!!\e[39m Configuración en archivo no válida \e[91m!!!\e[39m" "!!! Configuración en archivo no válida !!!"
						finalizarEjecucion 31;;
				esac
			else log 0 'Es comentario' '@'; fi
		fi
	done
	set +f; unset IFS
	if [ ! $i -eq 0 ]; then
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
		paginas+="$(expr $direccion / $proc_pagina_tamano),"
	done
	echo "${paginas::-1}"
}

#######################################
#	Muestra datos por pantalla
#	Globales:
#		mem_paginas
#		mem_paginas_secuencia
#		mem_proc_id
#		mem_proc_index
#		proc_color
#		proc_id
#		proc_paginas
#		proc_posicion
#		proc_tamano
#		proc_tiempo_ejecucion_restante
#		swp_proc_id
#		swp_proc_index
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function actualizarInterfaz() {
	local -i i
	header 2
	printf "\e[38;5;17m#\e[39m     \e[4m%s\e[0m     \e[38;5;18m#\e[39m     \e[4m%s\e[0m     \e[38;5;18m~\e[39m   \e[4m%s\e[0m   \e[38;5;18m~\e[39m     \e[4m%s\e[0m      \e[38;5;17m#\e[39m\n" "SWAP" "ID" "T. RESTANTE" "POSICIONES EN MEMORIA" #crea la cabecera de la tabla
	for i in {0..10}; do
		echo -ne '\e[38;5;17m#\e[39m'
		if [[ ! -z ${swp_proc_id[$i]} ]]; then
			echo -ne "\e[${proc_color[${swp_proc_index[$i]}]}m"
			if [[ ${proc_tamano[${swp_proc_index[$i]}]} -lt 10 ]]; then
				printf "%9s\e[0m (\e[${proc_color[${swp_proc_index[$i]}]}m%d\e[0m)" "${swp_proc_id[$i]:0:9}" "${proc_tamano[${swp_proc_index[$i]}]}"
			elif [[ ${proc_tamano[${swp_proc_index[$i]}]} -lt 100 ]]; then
				printf "%8s (\e[${proc_color[${swp_proc_index[$i]}]}m%d\e[0m)" "${swp_proc_id[$i]:0:8}" "${proc_tamano[${swp_proc_index[$i]}]}"
			else
				printf "%7s (\e[${proc_color[${swp_proc_index[$i]}]}m>99\e[0m)" "${swp_proc_id[$i]:0:7}"
			fi
		else
			printf "%13s" " "
		fi
		echo -ne ' \e[38;5;18m#\e[39m '
		if [[ ! -z ${mem_proc_index[$i]} ]]; then
			printf "\e[${proc_color[${mem_proc_index[$i]}]}m%10s\e[0m \e[38;5;18m~\e[39m %5s\e[${proc_color[${mem_proc_index[$i]}]}m%4d\e[0m%6s \e[38;5;18m~\e[39m \e[${proc_color[${mem_proc_index[$i]}]}m%-30s\e[0m " "${mem_proc_id[$i]:0:10}" " " "${proc_tiempo_ejecucion_restante[${mem_proc_index[$i]}]}" " " "${proc_posicion[${mem_proc_index[$i]}]:0:30}" #pone los datos en la tabla
		else
			printf "%10s \e[38;5;18m~\e[39m %15s \e[38;5;18m~\e[39m %31s" " " " " " " #si esta vacio solo pone el swap
		fi
		echo -ne '\e[0;38;5;17m#\e[39m\n'
	done
	header 0
	echo -ne '\e[38;5;17m#\e[39m '
	for i in {0..24}; do
		if [[ $i -ne 0 ]] && ([[ ${mem_paginas[$i]} -ne ${mem_paginas[$(expr $i - 1)]} ]] || ([[ -z ${mem_paginas[$i]} ]] && [[ ! -z ${mem_paginas[$(expr $i - 1)]} ]])); then
			case $i in
				0|1|24) echo -ne '\e[38;5;17m';;
				[2-4]|21[1-3]) echo -ne '\e[38;5;18m';;
				[5-7]|18|19|20|21) echo -ne '\e[38;5;19m';;
				*) echo -ne '\e[38;5;20m';;
			esac
			echo -n '|'
		else
			echo -n ' '
		fi
		if [[ -z ${mem_paginas[$i]} ]]; then
			echo -ne '\e[38;5;236m##\e[0m' #imprime # en verde si esta vacia la pagina
		else
			printf "\e[${proc_color[${mem_paginas[$i]}]}m%2d\e[0m" "${mem_paginas_secuencia[${i}]}" #sino en rojo imprime la pagina
		fi
	done
	echo -ne '  \e[38;5;17m#\e[39m\n'
	header 0
}

#######################################
#	Realiza un paso de tiempo
#	Globales:
#		evento
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
	if [[ $tiempo -le $tiempo_final ]]; then poblarSwap; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then poblarMemoria; fi
	if [[ ${#mem_proc_id[@]} -eq 0 ]]; then
		if [[ ${#swp_proc_id[@]} -eq 0 ]] && [[ $tiempo -gt $tiempo_final ]]; then finalizarEjecucion 0; fi
		if [[ ${proc_tamano[${swp_proc_index[0]}]} -gt $mem_tamano ]]; then finalizarEjecucion 20; fi
	else ejecucion; fi
	if [[ ! -z $tiempo_break ]] && [[ $(expr $tiempo + 1) -eq $tiempo_break ]]; then
		modo_debug=1
		if [[ ! -z $modo_silencio ]]; then
			modo_silencio_break=1
			notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion" #abrevia la memoria
			notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
			notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"
			unset modo_silencio
		fi
	fi
	if [[ ! -z $tiempo_unbreak ]] && [[ $tiempo -eq $tiempo_unbreak ]]; then
		unset modo_debug
		stepLog
		actualizarInterfaz
		if [[ ! -z $modo_silencio_break ]]; then
			modo_silencio=1
			unset modo_silencio_break
		fi
	fi
	if [[ -z $modo_silencio ]]; then
		if [[ -z $modo_debug ]]; then
			if [[ ! -z $evento ]]; then
				stepLog
				actualizarInterfaz
				echo ${evento::-2}
				unset evento
				read -p "Presiona cualquier tecla para continuar " -n 1 -r
			fi
		else
			stepLog
			actualizarInterfaz
			echo ${evento::-2}
			unset evento
			read -p "Presiona cualquier tecla para continuar " -n 1 -r
		fi
	else
		if [[ ! -z $evento ]]; then
			stepLog
			log 3 "${evento::-2}" '@'
			log 3
			unset evento
		elif [[ ! -z $modo_debug ]]; then
			stepLog
			log 3
		fi
	fi
	tiempo=$(expr $tiempo + 1)
}

#######################################
#	Muestra datos por fichero
#	Globales:
#		mem_paginas
#		mem_paginas_secuencia
#		mem_proc_id
#		mem_proc_index
#		proc_color
#		proc_id
#		proc_paginas
#		proc_posicion
#		proc_tamano
#		proc_tiempo_ejecucion_restante
#		swp_proc_id
#		swp_proc_index
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function stepLog() {
	local linea linea_no_esc
	log 3 "$(header 0)" "$(printf "%0.s#" {1..80})"
	log 3 "$(printf "\e[38;5;17m#\e[39m%32sINSTANTE: %3d%33s\e[38;5;17m#\e[39m" " " "$tiempo" " ")" "$(printf "#%32sINSTANTE: %3d%33s#" " " "$tiempo" " ")"
	log 3 "$(header 0)" "$(printf "%0.s#" {1..80})"
	log 3 '\e[38;5;17m#\e[39m     \e[4mSWAP\e[0m     \e[38;5;18m#\e[39m     \e[4mID\e[0m     \e[38;5;18m~\e[39m   \e[4mT. RESTANTE\e[0m   \e[38;5;18m~\e[39m     \e[4mPOSICIONES EN MEMORIA\e[0m      \e[38;5;17m#\e[39m' '#     SWAP     #     ID     ~   T. RESTANTE   ~      POSICIONES EN MEMORIA     #'
	for i in {0..10}; do
		linea='\e[38;5;17m#\e[39m'; linea_no_esc='#'
		if [[ ! -z ${swp_proc_id[$i]} ]]; then
			linea+="\e[${proc_color[${swp_proc_index[$i]}]}m"
			if [[ ${proc_tamano[${swp_proc_index[$i]}]} -lt 10 ]]; then
				linea+="$(printf "%9s\e[0m (\e[${proc_color[${swp_proc_index[$i]}]}m%d\e[0m)" "${swp_proc_id[$i]:0:9}" "${proc_tamano[${swp_proc_index[$i]}]}")"
				linea_no_esc+="$(printf "%9s (%d)" "${swp_proc_id[$i]:0:9}" "${proc_tamano[${swp_proc_index[$i]}]}")"
			elif [[ ${proc_tamano[${swp_proc_index[$i]}]} -lt 100 ]]; then
				linea+="$(printf "%8s\e[0m (\e[${proc_color[${swp_proc_index[$i]}]}m%d\e[0m)" "${swp_proc_id[$i]:0:8}" "${proc_tamano[${swp_proc_index[$i]}]}")"
				linea_no_esc+="$(printf "%8s (%d)" "${swp_proc_id[$i]:0:8}" "${proc_tamano[${swp_proc_index[$i]}]}")"
			else
				linea+="$(printf "%7s\e[0m (\e[${proc_color[${swp_proc_index[$i]}]}m>99\e[0m)" "${swp_proc_id[$i]:0:7}")"
				linea_no_esc+="$(printf "%7s (>99)" "${swp_proc_id[$i]:0:9}")"
			fi
		else
			linea+='             '; linea_no_esc+='             '
		fi
		linea+=' \e[38;5;18m#\e[39m '; linea_no_esc+=' # '
		if [[ ! -z ${mem_proc_index[$i]} ]]; then
			linea+="$(printf "\e[${proc_color[${mem_proc_index[$i]}]}m%10s\e[0m \e[38;5;18m~\e[39m %5s\e[${proc_color[${mem_proc_index[$i]}]}m%4d\e[0m%6s \e[38;5;18m~\e[39m \e[${proc_color[${mem_proc_index[$i]}]}m%-30s\e[0m " "${mem_proc_id[$i]:0:10}" " " "${proc_tiempo_ejecucion_restante[${mem_proc_index[$i]}]}" " " "${proc_posicion[${mem_proc_index[$i]}]:0:30}")"
			linea_no_esc+="$(printf "%10s ~ %5s%4d%6s ~ %-30s " "${mem_proc_id[$i]:0:10}" " " "${proc_tiempo_ejecucion_restante[${mem_proc_index[$i]}]}" " " "${proc_posicion[${mem_proc_index[$i]}]:0:30}")"
		else
			linea+="$(printf "%10s \e[38;5;18m~\e[39m %15s \e[38;5;18m~\e[39m %31s" " " " " " ")"
			linea_no_esc+="$(printf "%10s ~ %15s ~ %31s" " " " " " ")"
		fi
		linea+='\e[38;5;17m#\e[39m'; linea_no_esc+='#'
		log 3 "$linea" "$linea_no_esc"
	done
	log 3 "$(header 0)" "$(printf "%0.s#" {1..80})"
	linea='\e[38;5;17m#\e[39m '; linea_no_esc='# '
	for i in {0..24}; do
		if [[ $i -ne 0 ]] && ([[ ${mem_paginas[$i]} -ne ${mem_paginas[$(expr $i - 1)]} ]] || ([[ -z ${mem_paginas[$i]} ]] && [[ ! -z ${mem_paginas[$(expr $i - 1)]} ]])); then
			case $i in
				0|1|24) linea+='\e[38;5;17m';;
				[2-4]|21[1-3]) linea+='\e[38;5;18m';;
				[5-7]|18|19|20|21) linea+='\e[38;5;19m';;
				*) linea+='\e[38;5;20m';;
			esac
			linea+='|'; linea_no_esc+='|'
		else
			linea+=' '; linea_no_esc+=' '
		fi
		if [[ -z ${mem_paginas[$i]} ]]; then
			linea+='\e[38;5;236m##\e[0m'; linea_no_esc+='=='
		else
			linea+="$(printf "\e[${proc_color[${mem_paginas[$i]}]}m%2d\e[0m" "${mem_paginas_secuencia[${i}]}")"
			linea_no_esc+="$(printf "%2d" "${mem_paginas_secuencia[${i}]}")"
		fi
	done
	log 3 "$linea  \e[38;5;17m#\e[39m" "$linea_no_esc  #"
	log 3 "$(header 0)" "$(printf "%0.s#" {1..80})"
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
			i=$(expr $i \* 1000)
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
			redondeado=$(expr $numero % $i / $(expr $i / 1000))
		fi
	done
}

#######################################
#	Mete procesos en swap
#	Globales:
#		evento
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
	for (( i=0 ; i<"${#proc_id[@]}"; i++ )); do
		if [[ "${proc_tiempo_llegada[$i]}" -eq $tiempo ]]; then
			evento+="${proc_id[$i]} > SWAP, "
			swp_proc_id+=("${proc_id[$i]}")
			swp_proc_index+=("$i")
		fi
	done
}

#######################################
#	Mete procesos en memoria
#	Globales:
#		evento
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
#		proc_tamano
#		swp_proc_id
#		swp_proc_index
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function poblarMemoria() {
	mem_usada=${#mem_paginas[@]} #memoria usada es igual al numero de paginas
	local -i espacio_valido=1 i j
	if [[ ! -z $swp_proc_id ]]; then #si la swap no es nulo lo que pasara a continuacion te sorprendera...
		until [[ "${proc_tamano[${swp_proc_index[0]}]}" -gt $(expr $mem_tamano - $mem_usada) ]] || [[ "${#swp_proc_id[@]}" -eq 0 ]] || [[ $espacio_valido -eq 0 ]]; do #mientras el tamaño del primer proceso en el swap sea mayor que la memoria libre o el numero de procesos del swap sea cero hacer...
			for ((i=0 ; i<=$(expr $mem_tamano - ${proc_tamano[${swp_proc_index[0]}]} ) ; i++ )); do #para i=0 hasta mayor que 500 menos el tamaño del primer proceso incrementar
				espacio_valido=1 #define variable local espacio valido igual a 1
				for ((j=0 ; j<"${proc_tamano[${swp_proc_index[0]}]}" ; j++ )); do #por cada tamaño del proceso
					if [[ -z "${mem_paginas[$(expr $i + $j)]}" ]]; then #si la memoria es nula
						espacio_valido=$(expr $espacio_valido \* 1) #entonces es valido
					else
						i=$(expr $i + $j) #sino pasa al siguiente bloque de memoria
						espacio_valido=0
						break
					fi
				done
				if [[ $espacio_valido -eq 1 ]]; then #si el espacio es valido entonces
					evento+="${swp_proc_id[0]} > MEM, "
					mem_proc_id+=("${swp_proc_id[0]}") #guarda la id
					mem_proc_index+=("${swp_proc_index[0]}") #guarda index
					mem_proc_tamano+=("${proc_tamano[${swp_proc_index[0]}]}") #guarda tamaño
					mem_usada=$(expr $mem_usada + ${proc_tamano[${swp_proc_index[0]}]} ) #y actualiza la memoria usada
					for ((j=0 ; j<"${proc_tamano[${swp_proc_index[0]}]}" ; j++ )); do #por cada tamaño del proceso
						mem_paginas[$(expr $i + $j)]="${swp_proc_index[0]}" #guarda la id de cada proceso de memoria en el espacio correspondiente
						mem_paginas_secuencia[$(expr $i + $j)]="$(echo ${proc_paginas[${swp_proc_index[0]}]} | cut -d ',' -f $((j+1))  )" #guarda la secuencia de paginas de cada proceso de memoria en el espacio correspondiente
					done
					actualizarPosiciones
					unset swp_proc_id[0] #saca el proceso del swap
					unset swp_proc_index[0] #saca el proceso del swap
					swp_proc_id=( "${swp_proc_id[@]}" ) #desfragmento el swap
					swp_proc_index=( "${swp_proc_index[@]}" ) #desfragmenta el swap
					break
				fi
			done
		done
	fi
	if [[ ! -z $swp_proc_id ]] && [[ "${proc_tamano[${swp_proc_index[0]}]}" -le $(expr $mem_tamano - $mem_usada) ]]; then
		defragmentarMemoria
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
#		mem_paginas
#		mem_proc_id
#		mem_proc_index
#		mem_proc_tamano
#		mem_tamano
#		mem_usada
#		mem_usada_abreviacion
#		mem_usada_redondeado
#		modo_silencio
#		proc_posicion
#	Argumentos:
#		Indice de proceso
#		Indice de memoria
#	Devuelve:
#		Nada
#######################################
function eliminarMemoria() {
	local -ri index_objetivo=$1 index_mem_objetivo=$2
	local -i i
	for (( i=0 ; i<$mem_tamano ; i++ )); do
		if [[ ! -z ${mem_paginas[$i]} ]] && [[ ${mem_proc_index[$index_mem_objetivo]} -eq ${mem_paginas[$i]} ]]; then #si la id del proceso es igual a la id del que buscasa entonces...
			unset mem_paginas[$i] #saca procesos de la memoria si
		fi
	done
	i=0
	for index in ${mem_proc_index[@]}; do #por cada indice en memoria hacer...
		if [[ $index_objetivo -eq $index ]]; then #si lo encuentras entonces...
			evento+="${mem_proc_id[$i]} > OUT, "
			unset mem_proc_index[$i] #saca el indice de memoria
			unset mem_proc_id[$i] #saca el id de memoria
			for pos in ${proc_posicion[$index]}; do #por cada posicion del proceso hacer...
				unset mem_paginas_secuencia[$pos] #saca las paginas
			done
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
function defragmentarMemoria() {
	local -i i j
	until [[ $(expr $pivot_final + 1) -eq $mem_usada ]]; do
		local -i pivot=-1 pivot_final=0 count=0
		for ((i=$(expr $mem_tamano - 1) ; i>=0 ; i-- )); do
			if [[ -z ${mem_paginas[$i]} ]]; then
				if [[ $pivot -gt 0 ]]; then ((count++)); fi
			else
				if [[ $pivot -lt 0 ]]; then pivot_final=$i; fi
				pivot=$i
			fi
		done
		if [[ ! $(expr $pivot_final + 1) -eq $mem_usada ]]; then
			for ((j=0 ; j<=$count ; j++ )); do # por cada hueco hace...
				for ((i=0 ; i<=$pivot_final ; i++ )); do #por cada proceso comprueba si hay un hueco a la izquierda
					if [[ -z ${mem_paginas[$i]} ]] && [[ ! -z ${mem_paginas[$(expr $i + 1)]} ]]; then #si hay hueco se mueve
						mem_paginas[$i]=${mem_paginas[$(expr $i + 1)]}
						mem_paginas_secuencia[$i]=${mem_paginas_secuencia[$(expr $i + 1)]}
						unset mem_paginas[$(expr $i + 1)]
						unset mem_paginas_secuencia[$(expr $i + 1)]
					fi
				done
			done
		fi
	done
	actualizarPosiciones
	evento+="DEFRAG, "
}

#######################################
#	Ejecuta un proceso en CPU
#	Globales:
#		mem_proc_index
#		proc_tiempo_ejecucion
#		proc_tiempo_ejecucion_restante
#	Argumentos:
#		Nada
#	Devuelve:
#		Nada
#######################################
function ejecucion() {
	local -i min=${proc_tiempo_ejecucion_restante[${mem_proc_index[0]}]} min_i=${mem_proc_index[0]} min_mem_index=0 i=0
	for index in ${mem_proc_index[@]}; do #por cada indice de la memoria hacer...
		if [[ ${proc_tiempo_ejecucion_restante[$index]} -lt $min ]]; then #si el tiempo de ejecucion es el menor
			min=${proc_tiempo_ejecucion_restante[$index]} #guardalo como nuevo minimo
			min_i=$index
			min_mem_index=$i
		fi
		((i++))
	done
	((--proc_tiempo_ejecucion_restante[$min_i]))
	((++proc_tiempo_ejecucion[$min_i]))
	if [[ ${proc_tiempo_ejecucion_restante[$min_i]} -eq 0 ]]; then
		eliminarMemoria $min_i $min_mem_index
	else
		actualizarPaginas $min_i
	fi
}

#######################################
#	Realiza sustitución de páginas
#	Globales:
#		mem_paginas_secuencia
#		mem_proc_index
#		proc_tamano
#		proc_tiempo_ejecucion
#	Argumentos:
#		Index de proceso
#	Devuelve:
#		Nada
#######################################
function actualizarPaginas() {
	local -ri index=$1 ejecucion=${proc_tiempo_ejecucion[${index}]}
	local -a paginas=()
	local -i fallo=1 primera_posicion=-1
	IFS=',' read -r -a paginas <<< "${proc_paginas[$index]}"
	local -r objetivo=${paginas[$ejecucion]}
	for posicion in ${proc_posicion[$index]}; do
		if [[ primera_posicion -eq -1 ]]; then primera_posicion=$posicion; fi
		if [[ ${mem_paginas_secuencia[$posicion]} -eq $objetivo ]]; then fallo=0; fi
	done
	if [[ $fallo -eq 1 ]]; then
		mem_paginas_secuencia[$(expr $ejecucion % ${proc_tamano[$index]} + $primera_posicion)]=$objetivo
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
		local -i inx=${mem_proc_index[$p]}
		for ((i=0; i<$mem_tamano; i++ )); do
			if [[ ${mem_paginas[$i]} -eq $inx ]] && [[ ! -z ${mem_paginas[$i]} ]]; then
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
	for tiempo in "${proc_tiempo_llegada[@]}"; do
		if [[ $tiempo -gt $tiempo_max ]]; then tiempo_max=$tiempo; fi #coge el tiempo de llegada maximo de todos los tiempos
	done
	echo $tiempo_max
}

#######################################
#	Calcula última llegada de proceso
#	Globales:
#		date
#		tiempo
#	Argumentos:
#		Código de error
#	Devuelve:
#		Nada
#######################################
function finalizarEjecucion() {
	local -ri error=$1
	log 0 "TIEMPO DE EJECUCIÓN: ${SECONDS}s"
	if [[ $error -eq 0 ]]; then
		log 5 "ÚLTIMO TIEMPO: \e[44m$(expr $tiempo - 1)" "ÚLTIMO TIEMPO: <$(expr $tiempo - 1)>"
		log 9 "FINAL DE EJECUCIÓN CON FECHA \e[44m$(date)\e[49m" "FINAL DE EJECUCIÓN CON FECHA $(date)"
	else
		log 9 "\e[91m!!!\e[39m EXCEPCIÓN \e[91m${error}\e[39m CON FECHA \e[44m$(date)\e[49m \e[91m!!!\e[39m" "!!! EXCEPCIÓN <${error}> CON FECHA <$(date)> !!!"
	fi
	log 2 "$(header 0)" "$(printf "%0.s-" {1..80})"
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
		if [[ ! -z $mensaje ]]; then
			echo -e "[$(colorLog $nivel)${nivel}\e[39m] > ${mensaje}\e[0m" >> salida.txt
		else
			echo >> salida.txt
		fi
		if [[ ! -z $mensaje_noesc ]]; then
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
		log 1 "$(header 0)" "$(printf "%0.s#" {1..80})"
		log 1 "\e[38;5;17m#\e[39m$(printf "%78s" " ")\e[38;5;17m#\e[39m" "#$(printf "%78s" " ")#"
		log 1 "\e[38;5;17m#\e[39m                                 MIT License                                  \e[38;5;17m#\e[39m" "#                                 MIT License                                  #"
		log 1 "\e[38;5;17m#\e[39m                Copyright (c) 2017 Diego Gonzalez, Rodrigo Díaz               \e[38;5;17m#\e[39m" "#                Copyright (c) 2017 Diego Gonzalez, Rodrigo Díaz               #"
		log 1 "\e[38;5;17m#\e[39m            ――――――――――――――――――――――――――――――――――――――――――――――――――――――            \e[38;5;17m#\e[39m" "#            ――――――――――――――――――――――――――――――――――――――――――――――――――――――            #"
		log 1 "\e[38;5;17m#\e[39m         You may:                                                             \e[38;5;17m#\e[39m" "#         You may:                                                             #"
		log 1 "\e[38;5;17m#\e[39m           - Use the work commercially                                        \e[38;5;17m#\e[39m" "#           - Use the work commercially                                        #"
		log 1 "\e[38;5;17m#\e[39m           - Make changes to the work                                         \e[38;5;17m#\e[39m" "#           - Make changes to the work                                         #"
		log 1 "\e[38;5;17m#\e[39m           - Distribute the compiled code and/or source.                      \e[38;5;17m#\e[39m" "#           - Distribute the compiled code and/or source.                      #"
		log 1 "\e[38;5;17m#\e[39m           - Incorporate the work into something that                         \e[38;5;17m#\e[39m" "#           - Incorporate the work into something that                         #"
		log 1 "\e[38;5;17m#\e[39m             has a more restrictive license.                                  \e[38;5;17m#\e[39m" "#             has a more restrictive license.                                  #"
		log 1 "\e[38;5;17m#\e[39m           - Use the work for private use                                     \e[38;5;17m#\e[39m" "#           - Use the work for private use                                     #"
		log 1 "\e[38;5;17m#\e[39m$(printf "%78s" " ")\e[38;5;17m#\e[39m" "#$(printf "%78s" " ")#"
		log 1 "\e[38;5;17m#\e[39m         You must:                                                            \e[38;5;17m#\e[39m" "#         You must:                                                            #"
		log 1 "\e[38;5;17m#\e[39m           - Include the copyright notice in all                              \e[38;5;17m#\e[39m" "#           - Include the copyright notice in all                              #"
		log 1 "\e[38;5;17m#\e[39m             copies or substantial uses of the work                           \e[38;5;17m#\e[39m" "#             copies or substantial uses of the work                           #"
		log 1 "\e[38;5;17m#\e[39m           - Include the license notice in all copies                         \e[38;5;17m#\e[39m" "#           - Include the license notice in all copies                         #"
		log 1 "\e[38;5;17m#\e[39m             or substantial uses of the work                                  \e[38;5;17m#\e[39m" "#             or substantial uses of the work                                  #"
		log 1 "\e[38;5;17m#\e[39m$(printf "%78s" " ")\e[38;5;17m#\e[39m" "#$(printf "%78s" " ")#"
		log 1 "\e[38;5;17m#\e[39m         You cannot:                                                          \e[38;5;17m#\e[39m" "#         You cannot:                                                          #"
		log 1 "\e[38;5;17m#\e[39m           - Hold the author liable. The work is                              \e[38;5;17m#\e[39m" "#           - Hold the author liable. The work is                              #"
		log 1 "\e[38;5;17m#\e[39m             provided \"as is\".                                                \e[38;5;17m#\e[39m" "#             provided \"as is\".                                                #"
		log 1 "\e[38;5;17m#\e[39m$(printf "%78s" " ")\e[38;5;17m#\e[39m" "#$(printf "%78s" " ")#"
		log 1 "$(header 0)" "$(printf "%0.s#" {1..80})"
		log 1
	fi
	if [[ $nivel_log -le 3 ]]; then
		log 1 'CABECERA DEL PROGRAMA:' '@'
		log 3 "$(header 0)" "$(printf "%0.s#" {1..80})"
		log 3 "\e[38;5;17m#\e[39m$(printf "%78s" " ")\e[38;5;17m#\e[39m" "#$(printf "%78s" " ")#"
		log 3 "\e[38;5;17m#\e[39m                   \e[48;5;17mSRPT, Paginación, FIFO, Memoria Continua,\e[0m                  \e[38;5;17m#" "#                   SRPT, Paginación, FIFO, Memoria Continua,                  #"
		log 3 "\e[38;5;17m#\e[39m                  \e[48;5;17mFijas e iguales, Primer ajuste y Reubicable\e[0m                 \e[38;5;17m#" "#                  Fijas e iguales, Primer ajuste y Reubicable                 #"
		log 3 "\e[38;5;17m#\e[38;5;20m            ――――――――――――――――――――――――――――――――――――――――――――――――――――――            \e[38;5;17m#" "#            ――――――――――――――――――――――――――――――――――――――――――――――――――――――            #"
		log 3 "\e[38;5;17m#\e[96m           Alumnos:                                                           \e[38;5;17m#" "#           Alumnos:                                                           #"
		log 3 "\e[38;5;17m#\e[96m             - Gonzalez Roman, Diego                                          \e[38;5;17m#" "#             - Gonzalez Roman, Diego                                          #"
		log 3 "\e[38;5;17m#\e[96m             - Díaz García, Rodrigo                                           \e[38;5;17m#" "#             - Díaz García, Rodrigo                                           #"
		log 3 "\e[38;5;17m#\e[96m           Sistemas Operativos, Universidad de Burgos                         \e[38;5;17m#" "#           Sistemas Operativos, Universidad de Burgos                         #"
		log 3 "\e[38;5;17m#\e[96m           Grado en ingeniería informática (2016-2017)                        \e[38;5;17m#" "#           Grado en ingeniería informática (2016-2017)                        #"
		log 3 "\e[38;5;17m#\e[39m$(printf "%78s" " ")\e[38;5;17m#\e[39m" "#$(printf "%78s" " ")#"
		log 3 "$(header 0)" "$(printf "%0.s#" {1..80})"
		log 3
	fi
}

#_____________________________________________
# FINAL DE FUNCIONES
#
# COMIENZO DE PROGRAMA PRINCIPAL
#_____________________________________________

SECONDS=0
declare -a proc_id proc_tamano proc_paginas proc_tiempo_llegada proc_tiempo_ejecucion proc_tiempo_ejecucion_restante proc_posicion mem_paginas mem_proc_id mem_proc_index mem_proc_tamano swp_proc_id swp_proc_index
declare -i proc_count mem_tamano mem_usada=0 tiempo=-1 mem_tamano_redondeado mem_usada_redondeado proc_count_redondeado nivel_log=3
declare mem_tamano_abreviacion mem_usada_abreviacion proc_count_abreviacion
declare -ra proc_color_secuencia=(1,0 2,0 3,0 4,0 5,0 6,0 7,0 21,0 23,0 52,0 123,0 147,0 202,0 222,0 241,0) #fg,bg (88/256)

log 9
log 2 "$(header 0)" "$(printf "%0.s#" {1..80})"
log 9 "EJECUCIÓN DE \e[44m${0}\e[49m EN \e[44m$(hostname)\e[49m CON FECHA \e[44m$(date)\e[49m" "EJECUCIÓN DE <${0}> EN <$(hostname)> CON FECHA <$(date)>"
log 9

if [ ! $# -eq 0 ]; then
	log 5 'Argumentos introducidos, obteniendo información:' '@'
	leerArgs "$@"
fi

cabeceraLog

if [ $# -eq 0 ]; then #si no hay argumentos entonces...
	header 1 ; header 0
	log 5 'No Argumentos, comprobando modo de introduccion de datos:' '@'
	read -p 'Introducción de datos por archivo (s/n): ' -n 1 -r ; echo
	log 0 "RESPUESTA INPUT: \e[34m$REPLY\e[39m" "RESPUESTA INPUT: <$REPLY>"
	if [[ $REPLY =~ ^[SsYy]$ ]]; then #si la respuesta es S
		read -p 'Nombre del archivo: ' filename
		log 5 "Por archivo \e[34m${filename}\e[39m" "Por archivo <${filename}>"
		leerArchivo
	else log 5 'Por teclado' '@';	fi
elif [[ -z $modo_silencio ]]; then header 1 ; header 0; fi #en caso de que sea en modo silencioso entonces...

pedirDatos

if [[ -z $modo_silencio ]]; then #si no es modo silecioso
	notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion" #abrevia la memoria
	notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
	notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"
fi

while true ; do step ; done
