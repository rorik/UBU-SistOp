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
			until [[ "${proc_tamano[$i]}" =~ ^[0-9]+$ ]] && [[ ! "${proc_tamano[$i]}" -eq 0 ]]; do
				printf "\e[1A%80s\r" " "
				read -p "[P${i}] Bloques en memoria: " proc_tamano[$i]
				printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r"
			done
			printf "%80s\n" " "

			until [[ "${proc_tiempo_llegada[$i]}" =~ ^[0-9]+$ ]]; do
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
		done
	fi
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
				  log 3 "  Establecido nivel de log a $2"
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
	if [ ! -z "$filename" ]; then leerArchivo; fi
	if [ ! -z "$tmp_mem_tamano" ]; then mem_tamano=$tmp_mem_tamano; fi
}

function leerArchivo() {
	if [ ! -f $filename ]; then
		echo "Archivo \"${filename}\" no válido."
		finalizarEjecucion 30
	fi
	i=0
	IFS=$'\n'; set -f; for line in $(<$filename); do
		line=$(echo $line | tr -d ' ' | tr -d '\r')
		if [[ ! $line =~ ^[#+] ]] && [[ ! -z $(echo $line) ]]; then
			proc_tamano[$i]=$(echo $line | cut -d ';' -f1)
			proc_paginas[$i]=$(echo $line | cut -d ';' -f2)
			proc_tiempo_llegada[$i]=$(echo $line | cut -d';' -f3)
			proc_id[$i]=$(echo $line | cut -d';' -f4)
			if [[ -z "${proc_id[$i]}" ]]; then proc_id[$i]="P${i}"; fi
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w)
			((i++))
		else
			if [[ $line =~ ^[+] ]]; then
				case $(echo $line | tr -d '+' | cut -d ':' -f1) in
					"MEMORIA")
						mem_tamano=$(echo $line | cut -d ':' -f2);;
					"SISTEMA")
						mem_sistema=$(echo $line | cut -d ':' -f2);;
					*)
						echo "CONFIGURACIÓN EN FICHERO NO VÁLIDA"
						finalizarEjecucion 31;;
				esac
			fi
		fi
	done; set +f; unset IFS
	if [ ! $i -eq 0 ]; then
		proc_count=$i
	fi
}

function actualizarInterfaz() {
	header 2
	for i in {0..10}; do
		echo -n "${swp_proc_id[$i]}  # ${mem_proc_index[$i]}  - ${mem_proc_id[$i]}  - ${mem_proc_tamano[$i]}"
		if [[ ! -z ${mem_proc_index[$i]} ]]; then echo " - ${proc_tiempo_ejecucion_restante[${mem_proc_index[$i]}]}"; else echo; fi
	done
}

function procSort() {
	local -n tmp_proc_id=$1
	local -n tmp_proc_tamano=$2
	local -n tmp_proc_tiempo=$3
	local tmp_proc_id_copia=("${tmp_proc_id[@]}")
	local tmp_proc_tamano_copia=("${tmp_proc_tamano[@]}")
	local tmp_proc_tiempo_copia=("${tmp_proc_tiempo[@]}")
	local tmp_proc_count="${#tmp_proc_id[@]}"
	local i=0

	for el in "${tmp_proc_id_copia[@]}"; do
		local ii=0
		local max=0
		for tm in "${tmp_proc_tiempo_copia[@]}"; do
			if [[ $tm -gt $max ]]; then
				max=$tm
				max_i=$ii
			fi
			((ii++))
		done
		tmp_proc_id[$(expr $tmp_proc_count - $i - 1)]="${tmp_proc_id_copia[$max_i]}"
		tmp_proc_tamano[$(expr $tmp_proc_count - $i - 1)]="${tmp_proc_tamano_copia[$max_i]}"
		tmp_proc_tiempo[$(expr $tmp_proc_count - $i - 1)]="${tmp_proc_tiempo_copia[$max_i]}"
		unset tmp_proc_id_copia[$max_i]
		unset tmp_proc_tamano_copia[$max_i]
		unset tmp_proc_tiempo_copia[$max_i]
		tmp_proc_id_copia=( "${tmp_proc_id_copia[@]}" )
		tmp_proc_tamano_copia=( "${tmp_proc_tamano_copia[@]}" )
		tmp_proc_tiempo_copia=( "${tmp_proc_tiempo_copia[@]}" )
		((i++))
	done
}

function step() {
	read -p "Presiona cualquier tecla para continuar " -n 1 -r
	if [[ $tiempo -le $tiempo_final ]]; then popularSwap $tiempo; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then
		popularMemoria
		if [[ ! ${#mem_proc_id[@]} -eq 0 ]]; then ejecucion; fi
	else
		if [[ ! ${#mem_proc_id[@]} -eq 0 ]]; then ejecucion; else finalizarEjecucion 0; fi
	fi
	tiempo=$(expr $tiempo + 1)
  actualizarInterfaz
	echo "mem_usada: ${#mem_paginas[@]}"
	printf "%s " "${mem_paginas[@]}"
}

function stepSilencio() {
	if [[ $tiempo -le $tiempo_final ]]; then popularSwap $tiempo; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then
		popularMemoria
		if [[ ! ${#mem_proc_id[@]} -eq 0 ]]; then ejecucion; fi
	else
		if [[ ! ${#mem_proc_id[@]} -eq 0 ]]; then ejecucion; else finalizarEjecucion 0; fi
	fi
	tiempo=$(expr $tiempo + 1)
}

function getIndex() {
	local tmp_valor="${1}"
	shift
	local tmp_array=("${@}")

	for i in "${!tmp_array[@]}"; do
	   if [[ "${tmp_array[$i]}" = "${tmp_valor}" ]]; then
		   echo "${i}";
	   fi
	done
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
						#echo "+ $(expr $i + $j)"
						espacio_valido=$(expr $espacio_valido \* 1)
					else
						#echo "- $(expr $i + $j)"
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
						mem_paginas[$(expr $i + $j)]="${swp_proc_id[0]}"
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
			if [[ ${mem_proc_id[$index_mem_objetivo]} = ${mem_paginas[$i]} ]]; then
				unset mem_paginas[$i]
			else
				echo "NOPE ${mem_proc_id[$index_mem_objetivo]} != $pagina @ $i -> (${mem_paginas[$(expr $i - 1)]}) ${mem_paginas[$i]} (${mem_paginas[$(expr $i + 1)]})"
			fi
		fi
	done
	i=0
	for index in ${mem_proc_index[@]}; do
		if [[ $index_objetivo -eq $index ]]; then
			unset mem_proc_index[$i]
			unset mem_proc_id[$i]
			unset mem_proc_tamano[$i]
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
	if [[ ${proc_tiempo_ejecucion_restante[$min_i]} -eq 0 ]]; then
		eliminarMemoria $min_i $min_mem_index
	fi
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

#_____________________________________________
# FINAL DE FUNCIONES
#
# COMIENZO DE PROGRAMA PRINCIPAL
#_____________________________________________

nivel_log=3
log 9 "EJECUCIÓN DE ${0} EN $(hostname) CON FECHA $(date)"
log 9
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
else
	log 5 'Argumentos introducidos, obteniendo información:'
	leerArgs "$@"
	if [[ -z $modo_silencio ]]; then header 1 ; header 0; fi
fi

pedirDatos

tiempo_final="$(ultimoTiempo)"

notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion"
notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"

if [[ -z $modo_silencio ]]; then
	actualizarInterfaz
	while true ; do step ; done
else
	while true ; do stepSilencio ; done
fi
