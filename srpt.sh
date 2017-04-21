#! /bin/bash
echo "#############################################################" >> informe.txt
echo "#                        MIT License                        #" >> informe.txt
echo "#      Copyright (c) 2017 Diego Gonzalez, Rodrigo Díaz      #" >> informe.txt
echo "#                                                           #" >> informe.txt
echo "#                         You may:                          #" >> informe.txt
echo "#       - Use the work commercially                         #" >> informe.txt
echo "#       - Make changes to the work                          #" >> informe.txt
echo "#       - Distribute the compiled code and/or source.       #" >> informe.txt
echo "#       - Incorporate the work into something that          #" >> informe.txt
echo "#         has a more restrictive license.                   #" >> informe.txt
echo "#       - Use the work for private use                      #" >> informe.txt
echo "#                                                           #" >> informe.txt
echo "#                         You must:                         #" >> informe.txt
echo "#       - Include the copyright notice in all               #" >> informe.txt
echo "#         copies or substantial uses of the work            #" >> informe.txt
echo "#       - Include the license notice in all copies          #" >> informe.txt
echo "#         or substantial uses of the work                   #" >> informe.txt
echo "#                                                           #" >> informe.txt
echo "#                        You cannot:                        #" >> informe.txt
echo "#       - Hold the author liable. The work is               #" >> informe.txt
echo "#         provided \"as is\".                                 #" >> informe.txt
echo "############################################################" >> informe.txt

echo "#######################################################################" >> informe.txt
echo "#                                                                     #" >> informe.txt
echo "#              SRPT, Paginación, FIFO, Memoria Continua,              #" >> informe.txt
echo "#             Fijas e iguales, Primer ajuste y Reubicable             #" >> informe.txt
echo "#             -------------------------------------------             #" >> informe.txt
echo "#     Alumnos:                                                        #" >> informe.txt
echo "#       - Gonzalez Roman, Diego                                       #" >> informe.txt
echo "#       - Díaz García, Rodrigo                                        #" >> informe.txt
echo "#     Sistemas Operativos, Universidad de Burgos                      #" >> informe.txt
echo "#     Grado en ingeniería informática (2016-2017)                     #" >> informe.txt
echo "#                                                                     #" >> informe.txt
echo "#######################################################################" >> informe.txt

#_____________________________________________
# COMIENZO DE FUNCIONES
#_____________________________________________

function header() {
	if [ $1 -eq 0 ]; then
		clear
		clear
		header 1
		echo -e "\e[38;5;17m#\e[0m           \e[48;5;17mAlgoritmo SRPT, con paginación FIFO de memoria continua\e[0m            \e[38;5;17m#"
		echo -e "\e[38;5;17m#\e[0m         \e[48;5;17mde particiones fijas e iguales, ajuste primero y reubicable\e[0m          \e[38;5;17m#"
	elif [ $1 -eq 1 ]; then
		for i in {17..21} {21..17} ; do echo -en "\e[38;5;${i}m########" ; done ; echo -e "\e[0m"
	else
		header 0
		printf "\e[38;5;17m#\e[0m        \e[48;5;17mBloques Utilizables de Memoria: "
		if [[ -z $mem_tamano_abreviacion ]]; then
			printf " %3d, " "$mem_tamano_redondeado"
		else
			printf "%3d%1s, " "$mem_tamano_redondeado" "$mem_tamano_abreviacion"
		fi
		printf "Número de Procesos: "
		if [[ -z $proc_count_abreviacion ]]; then
			printf " %3d" "$proc_count_redondeado"
		else
			printf "%3d%1s" "$proc_count_round" "$proc_count_abreviacion"
		fi
		printf "\e[0m        \e[38;5;17m#\n"
		header 1
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
		-f|--filename)
		  if [ -n "$2" ]; then
			filename="$2"
			shift 2
			continue
		  else
			echo "ERROR: '--filename' requiere un argumento no vacio."
			exit 1
		  fi
			;;
		-m|--memoria)
		  if [ -n "$2" ]; then
			local tmp_mem_tamano="$2"
			shift 2
			continue
		  else
			echo "ERROR: '--memoria' requiere un argumento no vacio."
			exit 1
		  fi
			;;
		-p|--procesos)
		  if [ -n "$2" ]; then
			proc_count="$2"
			shift 2
			continue
		  else
			echo "ERROR: '--procesos' requiere un argumento no vacio."
			exit 1
		  fi
			;;
		--)
		  shift
		  break
		  ;;
		-?*)
		  echo "WARN: OPCIÓN DESCONOCIDA: $1"
		  ;;
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
		exit 1
	fi
	i=0
	IFS=$'\n'; set -f; for line in $(<$filename); do
		line=$(echo $line | tr -d ' ' | tr -d '\r')
		if [[ ! $line =~ ^[#+] ]] && [[ ! -z $(echo $line) ]]; then
			proc_tamano[$i]=$(echo $line | cut -d ';' -f1)
			proc_paginas[$i]=$(echo $line | cut -d ';' -f2)
			proc_tiempo_llegada[$i]=$(echo $line | cut -d';' -f3)
			proc_id[$i]=$(echo $line | cut -d';' -f4)
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w)
			((i++))
		else
			if [[ $line =~ ^[+] ]]; then
				case $(echo $line | tr -d '+' | cut -d ':' -f1) in
					"MEMORIA")
						mem_tamano=$(echo $line | cut -d ':' -f2)
						;;
					"SISTEMA")
						mem_sistema=$(echo $line | cut -d ':' -f2)
						;;
					*)
						echo "CONFIGURACIÓN EN FICHERO NO VÁLIDA"
						exit 1
						;;
				esac
			fi
		fi
	done; set +f; unset IFS
	if [ ! $i -eq 0 ]; then
		proc_count=$i
	fi
}

function actualizarInterfaz(){
	mem_used=0
	for proc in "${proc_size[@]}"; do
		mem_used=$(expr $mem_used + $proc)
	done
	mem_used_round=$(expr $mem_used \* 200  / $mem_tamano)
	
	header 2
	
	# echo -ne "\e[38;5;17m#" ; for i in {1..50}; do
		# if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	# done ; echo -ne "\e[38;5;20m#\e[0m"; echo "  TMÑO    TMPO     ID"
	
	# echo -ne "\e[38;5;17m#" ; for i in {51..100}; do
		# if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	# done ; echo -ne "\e[38;5;20m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[0]}" "${proc_time[0]}" "${proc_id[0]}"
	
	# echo -ne "\e[38;5;17m#" ; for i in {101..150}; do
		# if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	# done ; echo -ne "\e[38;5;20m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[1]}" "${proc_time[1]}" "${proc_id[1]}"
	
	# echo -ne "\e[38;5;17m#" ; for i in {151..200}; do
		# if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	# done ; echo -ne "\e[38;5;20m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[2]}" "${proc_time[2]}" "${proc_id[2]}"
	
	# for i in {17..21} {21..21} ; do echo -ne "\e[38;5;${i}m########" ; done ; echo -ne "\e[38;5;20m####\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[3]}" "${proc_time[3]}" "${proc_id[3]}"
	
	# tmp_swp_rows=5
	# tmp_swp_len=50
	# tmp_swp_cur_row=1
	# tmp_swp_cur_len=0
	# tmp_swp_cur_el=0
	# while [[ $tmp_swp_cur_row -le $tmp_swp_rows ]]; do
		# tmp_swp_el="${swp_proc_id[$tmp_swp_cur_el]}"
		# tmp_swp_el_size="${#tmp_swp_el}"
		# tmp_swp_el_status="${swp_proc_status[$tmp_swp_cur_el]}"
		# if [[ ! -z $tmp_swp_el ]] && [[ $(expr $tmp_swp_cur_len + $tmp_swp_el_size + 4) -lt $tmp_swp_len ]]; then
			# if [[ $tmp_swp_cur_len -eq 0 ]]; then
				# echo -ne "\e[38;5;17m#\e[0m "
				# if [[ $tmp_swp_el_status -eq 0 ]]; then echo -ne "${tmp_swp_el}"
				# elif [[ $tmp_swp_el_status -eq 1 ]]; then echo -ne "\e[31m${tmp_swp_el}\e[39m"
				# else echo -ne"\e[32m${tmp_swp_el}\e[39m"
				# fi
				# tmp_swp_cur_len=$(expr $tmp_swp_cur_len + $tmp_swp_el_size)
			# else
				# echo -ne ", "
				# if [[ $tmp_swp_el_status -eq 0 ]]; then echo -n "${tmp_swp_el}"
				# elif [[ $tmp_swp_el_status -eq 1 ]]; then echo -ne "\e[31m${tmp_swp_el}\e[39m"
				# else echo -ne"\e[32m${tmp_swp_el}\e[39m"
				# fi
				# tmp_swp_cur_len=$(expr $tmp_swp_cur_len + $tmp_swp_el_size + 2)
			# fi
			# ((tmp_swp_cur_el++))
		# else
			# if [[ $tmp_swp_cur_len -eq 0 ]]; then
				# printf "\e[38;5;17m#\e[0m%50c" ' '
			# else
				# printf  "%*s" "$(expr $tmp_swp_len - $tmp_swp_cur_len - 1)" ""
			# fi
			# echo -ne "\e[38;5;20m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[$(expr $tmp_swp_cur_row + 3)]}" "${proc_time[$(expr $tmp_swp_cur_row + 3)]}" "${proc_id[$(expr $tmp_swp_cur_row + 3)]}"
			# tmp_swp_cur_len=0
			# ((tmp_swp_cur_row++))
		# fi
	# done
	# header 1
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
	echo -e "\e[38;5;17m#\e[0m 1.- Introducir proceso en memoria"
	echo -e "\e[38;5;17m#\e[0m 2.- Sacar proceso de memoria"
	echo -e "\e[38;5;17m#\e[0m 3.- Ejecución"
	echo -e "\e[38;5;17m#\e[0m 4.- SRPT sort"
	echo -e "\e[38;5;17m#\e[0m 5.- Finalizar"
	header 1
	
	until [[ $REPLY =~ ^[1-5] ]]; do
		read -p  "Opción: " -n 1 -r; printf "\r         \r"
	done
	
	if [[ $REPLY -eq 1 ]]; then
		echo; echo -en "Añadir Proceso\e[1A\r"
		read -p "ID del proceso: " id
		tmp_index=$(getIndex "$id" "${swp_proc_id[@]}")
		if [[ ! -z $tmp_index ]]; then 
			tmp_mem_index=$(getIndex "$id" "${proc_id[@]}")
			if [[ -z $tmp_mem_index ]]; then 
				proc_id+=("$id")
				proc_size+=("${swp_proc_size[$tmp_index]}")
				proc_time+=("${swp_proc_time[$tmp_index]}")
				swp_proc_status[$tmp_index]=1
			fi
		fi
	elif [[ $REPLY -eq 2 ]]; then
		echo; echo -en "Sacar Proceso\e[1A\r"
		read -p "ID del proceso: " id
		tmp_mem_index=$(getIndex "$id" "${proc_id[@]}")
		if [[ ! -z $tmp_mem_index ]]; then 
			unset proc_id[$tmp_mem_index]
			unset proc_size[$tmp_mem_index]
			unset proc_time[$tmp_mem_index]
			unset swp_proc_status[$(getIndex "$id" "${swp_proc_id[@]}")]
			proc_id=( "${proc_id[@]}" )
			proc_size=( "${proc_size[@]}" )
			proc_time=( "${proc_time[@]}" )
		fi
	elif [[ $REPLY -eq 3 ]]; then
		echo
	elif [[ $REPLY -eq 4 ]]; then
		procSort proc_id proc_size proc_time
	elif [[ $REPLY -eq 5 ]]; then
		exit 1
	fi
	
	REPLY=
	actualizarInterfaz
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
				abreviacion=
				;;
			"1000000")
				abreviacion="K"
				;;
			"1000000000")
				abreviacion="M"
				;;
			"1000000000000")
				abreviacion="G"
				;;
			"1000000000000000")
				abreviacion="T"
				;;
			*)
				abreviacion="?"
				;;
			esac
			redondeado=$(expr $numero % $i / $(expr $i / 1000))
		fi
	done
}

#_____________________________________________
# FINAL DE FUNCIONES
#_____________________________________________

header 0 ; header 1

if [ $# -eq 0 ]; then
	read -p "Introducción de datos por archivo (s/n): " -n 1 -r ; echo
	if [[ $REPLY =~ ^[SsYy]$ ]]; then
		read -p "Nombre del archivo: " filename
		leerArchivo
	fi
else
	leerArgs "$@"
fi

pedirDatos

notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion"
notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"

actualizarInterfaz
#while true ; do step ; done
