#! /bin/bash

#_____________________________________________
# COMIENZO DE FUNCIONES
#_____________________________________________

function header() {
	if [ $1 -eq 0 ]; then
		for i in {17..21} {21..17} ; do echo -en "\e[38;5;${i}m########" ; done ; echo -e "\e[0m"
	elif [ $1 -eq 1 ]; then
		clear
		clear
		header 0
		echo -e "\e[38;5;17m#\e[0m\e[48;5;17mSRPT, PAGINACIÓN FIFO, MEMORIA CONT, PARTES FIJAS IGUAL, 1er AJUSTE REUBICABLE\e[0m\e[38;5;17m#"
	else
		header 1
		printf "\e[38;5;17m#\e[0m     \e[48;5;17mTamaño de Memoria: "
		if [[ -z $mem_tamano_abreviacion ]]; then
			printf " %3d" "$mem_tamano_redondeado"
		else
			printf "%3d%1s" "$mem_tamano_redondeado" "$mem_tamano_abreviacion"
		fi
		printf "\e[0m     \e[48;5;17mTiempo: %3d\e[0m     \e[48;5;17mNúmero de Procesos: " "$tiempo"
		if [[ -z $proc_count_abreviacion ]]; then
			printf " %3d" "$proc_count_redondeado"
		else
			printf "%3d%1s" "$proc_count_round" "$proc_count_abreviacion"
		fi
		printf "\e[0m     \e[38;5;17m#\n"
		header 0
	fi
}

function pedirDatos() {
	if [ -z "$mem_tamano" ]; then
		until [[ $mem_tamano =~ ^[0-9]+$ ]] && [[ ! $mem_tamano -eq 0 ]]; do
			printf "\e[1A%80s\r" " "
			read -p "Tamaño (en bloques) de la memoria: " mem_tamano
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
			read -p "[P${i}] Secuencia de páginas: " proc_paginas[$i]
			echo

			proc_id[$i]="P${i}"
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w)
			log 3 "    Proceso ${i}, con ID <${proc_id[$i]}>, Secuencia <${proc_paginas[$i]}>, Bloques <${proc_tamano[$i]}>, Llegada <${proc_tiempo_llegada[$i]}>"
		done
	fi

	tiempo_final="$(ultimoTiempo)"
}

function leerArgs() {
	while [ "$1" != "" ]; do
		case $1 in
			-s|--silencio)
				modo_silencio=1
				log 9 '  Salida gráfica deshabilitada'
			;;
			-f|--filename)
			  if [ -n "$2" ]; then
					filename="$2"
					log 5 "  Argumento de archivo introducido <${filename}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--filename" requiere un argumento no vacio.'
					log 9 '!!! El argumento filename contiene errores !!!'
					finalizarEjecucion 40
			  fi;;
			-m|--memoria)
			  if [ -n "$2" ]; then
					local tmp_mem_tamano="$2"
					log 5 "  Argumento de memoria introducido <${tmp_mem_tamano}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--memoria" requiere un argumento no vacio.'
					log 9 '!!! El argumento memoria contiene errores !!!'
					finalizarEjecucion 41
			  fi;;
			-p|--procesos)
			  if [ -n "$2" ]; then
					proc_count="$2"
					log 5 "  Argumento de procesos introducido <${proc_count}>"
					shift 2
					continue
			  else
					echo 'ERROR: "--procesos" requiere un argumento no vacio.'
					log 9 '!!! El argumento procesos contiene errores !!!'
					finalizarEjecucion 42
			  fi;;
			-l|--log)
			  if [ -n "$2" ]; then
					nivel_log="$2"
				  log 5 "  Establecido nivel de log a $nivel_log"
					shift 2
					continue
			  else
					echo 'ERROR: "--log" requiere un argumento no vacio.'
					log 9 '!!! El argumento log contiene errores !!!'
					finalizarEjecucion 43
			  fi;;
			-?*)
			log 4 "^^^ OPCIÓN \"${1}\" DESCONOCIDA ^^^";;
			*)
		  break
	  esac
	  shift
	done
	if [ ! -z "$filename" ]; then
		log 3 "  Leyendo archivo:"
		leerArchivo
		log 0 "  Fin Lectura archivo"
	fi
	if [ ! -z "$tmp_mem_tamano" ]; then
		mem_tamano=$tmp_mem_tamano
		log 3 "  Tamaño de memoria asignado a $mem_tamano"
	fi
}

function leerArchivo() {
	if [ ! -f $filename ]; then
		log 9 'Archivo no existente'
		echo "Archivo \"${filename}\" no válido."
		finalizarEjecucion 30
	fi

	local i=0
	IFS=$'\n'; set -f
	for line in $(<$filename); do
		line=$(echo $line | tr -d ' ' | tr -d '\r')
		log 0 "    Linea leida <${line}>"
		if [[ ! $line =~ ^[\#+] ]] && [[ ! -z $line ]]; then
			log 0 "    Es proceso:"
			proc_tamano[$i]=$(echo $line | cut -d ';' -f1)
			log 0 "      Tamaño <${proc_tamano[$i]}>"
			proc_paginas[$i]=$(echo $line | cut -d ';' -f2)
			log 0 "      Secuecia <${proc_paginas[$i]}>"
			proc_tiempo_llegada[$i]=$(echo $line | cut -d';' -f3)
			log 0 "      Llegada <${proc_tiempo_llegada[$i]}>"
			proc_id[$i]=$(echo $line | cut -d';' -f4)
			log 0 "      ID <${proc_id[$i]}>"
			if [[ -z ${proc_id[$i]} ]]; then
				proc_id[$i]="P${i}"
				log 0 "      Nueva ID <${proc_id[$i]}>"
			fi
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w)
			log 3 "    Proceso ${i}, con ID <${proc_id[$i]}>, Secuencia <${proc_paginas[$i]}>, Bloques <${proc_tamano[$i]}>, Llegada <${proc_tiempo_llegada[$i]}>"
			((i++))
		else
			log 0 "    Es comando:"
			if [[ $line =~ ^[+] ]]; then
				log 0 "      Es opción:"
				case $(echo $line | tr -d '+' | cut -d ':' -f1) in
					"MEMORIA")
						mem_tamano=$(echo $line | cut -d ':' -f2)
						log 0 "        de memoria <${mem_tamano}>"
						log 3 "    Configuración, bloques de memoria <${mem_tamano}> ";;
					"SISTEMA")
						mem_sistema=$(echo $line | cut -d ':' -f2)
						log 0 "        de sistema <${mem_sistema}>"
						log 3 "    Configuración, bloques del sistema <${mem_sistema}> ";;
					*)
						echo 'CONFIGURACIÓN EN FICHERO NO VÁLIDA'
						finalizarEjecucion 31;;
				esac
			else log 0 "      Es comentario"; fi
		fi
	done
	set +f; unset IFS
	if [ ! $i -eq 0 ]; then
		proc_count=$i
	fi
}

function actualizarInterfaz() {
	header 2
	printf "%8s # %5s - %8s - %5s -  %6s - %3s\n" "  SWP   " " INX " "   ID   " " MEM " "TIEMPO" "POS"
	for i in {0..10}; do
		if [[ ! -z ${mem_proc_index[$i]} ]]; then
			printf "%8s #  %3d  - %8s -  %3d  -  %3d    - %s" "${swp_proc_id[$i]:0:8}" "${mem_proc_index[$i]}" "${mem_proc_id[$i]:0:8}" "${mem_proc_tamano[$i]}" "${proc_tiempo_ejecucion_restante[${mem_proc_index[$i]}]}" "${mem_proc_posicion[${mem_proc_index[$i]}]}"
		else printf "%9s#%7s-%10s-%7s-%9s-" " " " " " " " " " "; fi
		echo
	done
	for i in {0..20}; do
		if [[ -z ${mem_paginas[$i]} ]]; then
			echo -ne "\e[32m## "
		else
			printf "\e[31m%2d " "${mem_paginas_secuencia[${i}]}"
		fi
	done
	echo -e "\e[39m"
	echo "mem_usada: ${#mem_paginas[@]}"
}

function step() {
	read -p "Presiona cualquier tecla para continuar " -n 1 -r
	if [[ $tiempo -le $tiempo_final ]]; then popularSwap $tiempo; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then
		popularMemoria
	elif [[ ${#mem_proc_id[@]} -eq 0 ]]; then finalizarEjecucion 0; fi
	ejecucion
	tiempo=$(expr $tiempo + 1)
  actualizarInterfaz
}

function stepSilencio() {
	if [[ $tiempo -le $tiempo_final ]]; then popularSwap $tiempo; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then
		popularMemoria
	elif [[ ${#mem_proc_id[@]} -eq 0 ]]; then finalizarEjecucion 0; fi
	ejecucion
	tiempo=$(expr $tiempo + 1)
}

function notacionCientifica() {
	local i=1000
	local numero=$1
	local -n redondeado="$2"
	local -n abreviacion="$3"
	while [[ -z $redondeado ]]; do
		if [[ numero -gt $i ]]; then
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

function popularSwap() {
	local tiempo=$1
	local i=0
	for (( i=0 ; i<"${#proc_id[@]}"; i++ )); do
		if [[ "${proc_tiempo_llegada[$i]}" -eq $tiempo ]]; then
			swp_proc_id+=("${proc_id[$i]}")
			swp_proc_index+=("$i")
		fi
	done
}

function popularMemoria() {
	mem_usada=${#mem_paginas[@]}
	if [[ ! -z swp_proc_id ]]; then
		until [[ "${proc_tamano[${swp_proc_index[0]}]}" -gt $(expr $mem_tamano - $mem_usada) ]] || [[ "${#swp_proc_id[@]}" -eq 0 ]]; do
			for ((i=0 ; i<=$(expr 500 - ${proc_tamano[${swp_proc_index[0]}]} ) ; i++ )); do
				local espacio_valido=1
				for ((j=0 ; j<"${proc_tamano[${swp_proc_index[0]}]}" ; j++ )); do
					if [[ -z "${mem_paginas[$(expr $i + $j)]}" ]]; then
						espacio_valido=$(expr $espacio_valido \* 1)
					else
						i=$(expr $i + $j)
						espacio_valido=0
						break
					fi
				done
				if [[ $espacio_valido -eq 1 ]]; then
					mem_proc_id+=("${swp_proc_id[0]}")
					mem_proc_index+=("${swp_proc_index[0]}")
					mem_proc_tamano+=("${proc_tamano[${swp_proc_index[0]}]}")
					mem_usada=$(expr $mem_usada + ${proc_tamano[${swp_proc_index[0]}]} )
					for ((j=0 ; j<"${proc_tamano[${swp_proc_index[0]}]}" ; j++ )); do
						mem_paginas[$(expr $i + $j)]="${swp_proc_index[0]}"
						mem_paginas_secuencia[$(expr $i + $j)]="$(echo ${proc_paginas[${swp_proc_index[0]}]} | cut -d ',' -f $((j+1))  )"
						mem_proc_posicion[${swp_proc_index[0]}]="${mem_proc_posicion[${swp_proc_index[0]}]}$(expr $i + $j) "
					done
					break
				fi
			done
			unset swp_proc_id[0]
			unset swp_proc_index[0]
			swp_proc_id=( "${swp_proc_id[@]}" )
			swp_proc_index=( "${swp_proc_index[@]}" )
		done
	fi
}

function eliminarMemoria() {
	local index_objetivo=$1
	local index_mem_objetivo=$2
	local i=0
	local ii=0
	local mix=${#mem_paginas[@]}
	for (( i=0 ; ii<$mix ; i++ )); do
		if [[ ! -z ${mem_paginas[$i]} ]]; then
			((ii++))
			if [[ ${mem_proc_index[$index_mem_objetivo]} = ${mem_paginas[$i]} ]]; then
				unset mem_paginas[$i]
			fi
		fi
	done
	i=0
	for index in ${mem_proc_index[@]}; do
		if [[ $index_objetivo -eq $index ]]; then
			unset mem_proc_index[$i]
			unset mem_proc_id[$i]
			for pos in ${mem_proc_posicion[$index_objetivo]}; do
				unset mem_paginas_secuencia[$pos]
			done
			unset mem_proc_tamano[$i]
			unset mem_proc_posicion[$i]
			mem_proc_index=( "${mem_proc_index[@]}" )
			mem_proc_id=( "${mem_proc_id[@]}" )
			mem_proc_tamano=( "${mem_proc_tamano[@]}" )
		fi
		((i++))
	done
}

function ejecucion() {
	local min=${proc_tiempo_ejecucion_restante[${mem_proc_index[0]}]}
	local min_i=${mem_proc_index[0]}
	min_mem_index=0
	local i=0
	for index in ${mem_proc_index[@]}; do
		if [[ ${proc_tiempo_ejecucion_restante[$index]} -lt $min ]]; then
			min=${proc_tiempo_ejecucion_restante[$index]}
			min_i=$index
			min_mem_index=$i
		fi
		((i++))
	done
	((--proc_tiempo_ejecucion_restante[$min_i]))
	((++proc_tiempo_ejecucion[$min_i]))
	actualizarPaginas $min_i
	if [[ ${proc_tiempo_ejecucion_restante[$min_i]} -eq 0 ]]; then
		eliminarMemoria $min_i $min_mem_index
	fi
}

function actualizarPaginas() {
	local index=$1
	#for pagina in ${mem_paginas[@]}; do
		#if [[ index ]]
}

function ultimoTiempo() {
	local tiempo_max=0
	for tiempo in "${proc_tiempo_llegada[@]}"; do
		if [[ $tiempo -gt $tiempo_max ]]; then tiempo_max=$tiempo; fi
	done
	echo $tiempo_max
}

function finalizarEjecucion() {
	local error=$1
	if [[ $error -eq 0 ]]; then
		log 9 "FINAL DE EJECUCIÓN CON FECHA $(date)"
	else
		log 9 "EXCEPCIÓN [${error}] CON FECHA $(date)"
	fi
	exit $error
}

function log() {
	local nivel=$1
	local mensaje=$2
	if [[ $nivel -ge $nivel_log ]]; then
		if [[ ! -z $mensaje ]]; then
			echo "[${nivel}] > ${mensaje}" >> out.txt
		else
			echo >> out.txt
		fi
	fi
}

function cabeceraLog() {
	log 1 'LICENCIA DE USO:'
	log 1 '##########################################################################'
	log 1 '#                                                                        #'
	log 1 '#                              MIT License                               #'
	log 1 '#             Copyright (c) 2017 Diego Gonzalez, Rodrigo Díaz            #'
	log 1 '#         ――――――――――――――――――――――――――――――――――――――――――――――――――――――         #'
	log 1 '#      You may:                                                          #'
	log 1 '#        - Use the work commercially                                     #'
	log 1 '#        - Make changes to the work                                      #'
	log 1 '#        - Distribute the compiled code and/or source.                   #'
	log 1 '#        - Incorporate the work into something that                      #'
	log 1 '#          has a more restrictive license.                               #'
	log 1 '#        - Use the work for private use                                  #'
	log 1 '#                                                                        #'
	log 1 '#      You must:                                                         #'
	log 1 '#        - Include the copyright notice in all                           #'
	log 1 '#          copies or substantial uses of the work                        #'
	log 1 '#        - Include the license notice in all copies                      #'
	log 1 '#          or substantial uses of the work                               #'
	log 1 '#                                                                        #'
	log 1 '#      You cannot:                                                       #'
	log 1 '#        - Hold the author liable. The work is                           #'
	log 1 '#          provided "as is".                                             #'
	log 1 '#                                                                        #'
	log 1 '##########################################################################'
	log 1
	log 1 'CABECERA DEL PROGRAMA:'
	log 3 '##########################################################################'
	log 3 '#                                                                        #'
	log 3 '#                SRPT, Paginación, FIFO, Memoria Continua,               #'
	log 3 '#               Fijas e iguales, Primer ajuste y Reubicable              #'
	log 3 '#         ――――――――――――――――――――――――――――――――――――――――――――――――――――――         #'
	log 3 '#        Alumnos:                                                        #'
	log 3 '#          - Gonzalez Roman, Diego                                       #'
	log 3 '#          - Díaz García, Rodrigo                                        #'
	log 3 '#        Sistemas Operativos, Universidad de Burgos                      #'
	log 3 '#        Grado en ingeniería informática (2016-2017)                     #'
	log 3 '#                                                                        #'
	log 3 '##########################################################################'
	log 3
}

#_____________________________________________
# FINAL DE FUNCIONES
#
# COMIENZO DE PROGRAMA PRINCIPAL
#_____________________________________________

nivel_log=3

log 9 "EJECUCIÓN DE ${0} EN $(hostname) CON FECHA $(date)"
log 9

if [ ! $# -eq 0 ]; then
	log 5 'Argumentos introducidos, obteniendo información:'
	leerArgs "$@"
fi

cabeceraLog

declare -a mem_paginas=()
declare -i mem_usada=0

if [ $# -eq 0 ]; then
	header 1 ; header 0
	log 5 'No Argumentos, comprobando modo de introduccion de datos:'
	read -p 'Introducción de datos por archivo (s/n): ' -n 1 -r ; echo
	log 0 "  RESPUESTA INPUT: $REPLY"
	if [[ $REPLY =~ ^[SsYy]$ ]]; then
		read -p 'Nombre del archivo: ' filename
		log 5 "  Por archivo (${filename})"
		leerArchivo
	else log 5 '  Por teclado';	fi
elif [[ -z $modo_silencio ]]; then header 1 ; header 0; fi

pedirDatos

if [[ -z $modo_silencio ]]; then
	notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion"
	notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"
	actualizarInterfaz
	while true ; do step ; done
else
	while true ; do stepSilencio ; done
fi
