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
		echo -n "     " ; for i in {17..21} {21..17} ; do echo -en "\e[38;5;${i}m#######\e[0m" ; done ; echo
		echo -e "            \e[48;5;17mAlgoritmo SRPT, con paginación FIFO de memoria continua\e[0m"
		echo -e "          \e[48;5;17mde particiones fijas e iguales, ajuste primero y reubicable\e[0m"
	else
		echo -n "     " ; for i in {17..21} {21..17} ; do echo -en "\e[38;5;${i}m#######\e[0m" ; done ; echo
	fi
}

function pedirDatos() {
	if [ $1 -eq 0 ]; then
		if [ -z "$mem_size" ]; then
			until [[ $mem_size =~ ^[0-9]+$ ]] && [[ ! $mem_size -eq 0 ]]; do
				read -p "Tamaño (en bloques) de la memoria: " mem_size
			done
		fi
		if [ -z "$proc_count" ]; then
			until [[ $proc_count =~ ^[0-9]+$ ]] && [[ ! $proc_count -eq 0 ]]; do
				read -p "Número de procesos: " proc_count
			done
		fi
		if [ -z "$swp_proc_size" ]; then
			for i in $(seq 0 $(expr $proc_count - 1 )); do
				until [[ "${swp_proc_size[$i]}" =~ ^[0-9]+$ ]] && [[ ! "${swp_proc_size[$i]}" -eq 0 ]]; do
					read -p "[${i}] Bloques: " swp_proc_size[$i]
				done
				until [[ "${swp_proc_time[$i]}" =~ ^[0-9]+$ ]] && [[ ! "${swp_proc_time[$i]}" -eq 0 ]]; do
					read -p "[${i}] Tiempo: " swp_proc_time[$i]
				done
				swp_proc_id[$i]=$i
			done
		fi
	else
		until [[ $mem_size =~ ^[0-9]+$ ]] && [[ ! $mem_size -eq 0 ]]; do
			read -p "Tamaño (en bloques) de la memoria: " mem_size
		done
		until [[ $proc_count =~ ^[0-9]+$ ]] && [[ ! $proc_count -eq 0 ]]; do
			read -p "Número de procesos: " proc_count
		done
		for i in $(seq 0 $(expr $proc_count - 1 )); do
			until [[ "${swp_proc_size[$i]}" =~ ^[0-9]+$ ]] && [[ ! "${swp_proc_size[$i]}" -eq 0 ]]; do
				read -p "[${i}] Bloques: " swp_proc_size[$i]
			done
			until [[ "${swp_proc_time[$i]}" =~ ^[0-9]+$ ]] && [[ ! "${swp_proc_time[$i]}" -eq 0 ]]; do
				read -p "[${i}] Tiempo: " swp_proc_time[$i]
			done
			swp_proc_id[$i]=$i
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
			tmp_mem_size="$2"
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
	
	
	if [ ! -z "$proc_count" ]; then
		if [[ ! $proc_count =~ ^[0-9]+$ ]] || [[ $proc_count -eq 0 ]]; then
			proc_count=;
		fi
	fi
	if [ ! -z "$filename" ]; then leerArchivo; fi
	if [ ! -z "$tmp_mem_size" ]; then
		if [[ $tmp_mem_size =~ ^[0-9]+$ ]] && [[ ! $tmp_mem_size -eq 0 ]]; then
			mem_size=$tmp_mem_size;
		fi
	fi
	pedirDatos 0
}

function leerArchivo() {
	if [ ! -f $filename ]; then
		echo "Archivo \"${filename}\" no válido."
		exit 1
	fi
	i=0
	IFS=$'\n'; set -f; for line in $(<$filename); do
		if [[ ! $line =~ ^[#+] ]] && [[ ! -z $(echo $line | tr -d '\r') ]]; then
			swp_proc_size[$i]=$(echo $line | cut -d',' -f1 | tr -d ' ')
			swp_proc_time[$i]=$(echo $line | cut -d',' -f2 | tr -d ' ')
			swp_proc_id[$i]=$(echo $line | cut -d',' -f3 | tr -d ' ' | tr -d '\r')
			((i++))
		else
			if [[ $line =~ ^[+] ]]; then
				mem_size=$(echo $(echo $line | cut -d',' -f2) | tr -d ' ' | tr -d '\r')
			fi
		fi
	done; set +f; unset IFS
	if [ ! $i -eq 0 ]; then
		proc_count=$i
	fi
}

function actualizarInterfaz(){
	header 0
	echo -e "           \e[48;5;17mBloques Utilizables de Memoria: $mem_size , Número de Procesos: $proc_count\e[0m"
	header 1
	
	mem_used=0
	for proc in "${proc_size[@]}"; do
		mem_used=$(expr $mem_used + $proc)
	done
	mem_used_round=$(expr $mem_used \* 200  / $mem_size)
	
	echo -ne "\e[38;5;20m#" ; for i in {1..50}; do
		if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	done ; echo -ne "\e[38;5;20m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[0]}" "${proc_time[0]}" "${proc_id[0]}"
	
	echo -ne "\e[38;5;19m#" ; for i in {51..100}; do
		if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	done ; echo -ne "\e[38;5;19m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[1]}" "${proc_time[1]}" "${proc_id[1]}"
	
	echo -ne "\e[38;5;18m#" ; for i in {101..150}; do
		if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	done ; echo -ne "\e[38;5;18m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[2]}" "${proc_time[2]}" "${proc_id[2]}"
	
	echo -ne "\e[38;5;17m#" ; for i in {151..200}; do
		if [ "$mem_used_round" -ge "$i" ]; then echo -ne "\e[91m\u2593"; else echo -ne "\e[92m\u2593"; fi
	done ; echo -ne "\e[38;5;17m#\e[0m"; printf " %3s   - %3s   - %3s\n" "${proc_size[3]}" "${proc_time[3]}" "${proc_id[3]}"
	
	header 1
	echo -e "              \e[48;5;17mProcesos en Memoria: ${#proc_id[@]}\e[0m"
	tmp_swp_rows=5
	tmp_swp_len=50
	tmp_swp_cur_row=1
	tmp_swp_cur_len="${#swp_proc_id[0]}"
	tmp_swp_cur_el=1
	echo -ne "\e[38;5;20m#\e[0m ${swp_proc_id[0]}"
	while [[ $tmp_swp_cur_row -le $tmp_swp_rows ]]; do
		tmp_swp_el="${swp_proc_id[$tmp_swp_cur_el]}"
		tmp_swp_el_size="${#tmp_swp_el}"
		if [[ ! -z $tmp_swp_el ]] && [[ $(expr $tmp_swp_cur_len + $tmp_swp_el_size + 4) -lt $tmp_swp_len ]]; then
			if [[ $tmp_swp_cur_len -eq 0 ]]; then
				echo -ne "\e[38;5;20m#\e[0m ${tmp_swp_el}"
				tmp_swp_cur_len=$(expr $tmp_swp_cur_len + $tmp_swp_el_size)
			else
				echo -n ", ${tmp_swp_el}"
				tmp_swp_cur_len=$(expr $tmp_swp_cur_len + $tmp_swp_el_size + 2)
			fi
			((tmp_swp_cur_el++))
		else
			if [[ $tmp_swp_cur_len -eq 0 ]]; then
				echo -ne "\e[38;5;20m#\e[0m                                                  "
			else
				for (( i=$tmp_swp_cur_len; i<=$(expr $tmp_swp_len - 2); i++ )); do echo -n " "; done
			fi
			echo -e "\e[38;5;20m#\e[0m"
			tmp_swp_cur_len=0
			((tmp_swp_cur_row++))
		fi
	done
	header 1
}

function procSort() {
	local tmp_proc_time=("$@")
	local tmp_proc_size=("${proc_size[@]}")
	local tmp_proc_id=("${proc_id[@]}")
	for ((ii=0; ii<proc_count; ii++)); do
		local i=0
		local max=0
		for el in "${tmp_proc_time[@]}"; do
			if [[ $el -gt $max ]]; then
				max=$el
				max_i=$i
			fi
			((i++))
		done
		proc_size["$(expr $proc_count - $ii - 1)"]="${tmp_proc_size[${max_i}]}"
		proc_time["$(expr $proc_count - $ii - 1)"]="${max}"
		proc_id["$(expr $proc_count - $ii - 1)"]="${tmp_proc_id[${max_i}]}"
		tmp_proc_time["${max_i}"]=0
	done
}

function step() {
	echo "1.- Introducir proceso en memoria"
	echo "2.- Sacar proceso de memoria"
	echo "3.- Ejecución"
	echo "4.- SRPT sort"
	header 1
	
	until [[ $REPLY =~ ^[1-4] ]]; do
		read -p  "Opción: " -n 1 -r; printf "\r         \r"
	done
	
	if [[ $REPLY -eq 1 ]]; then
		read -p "ID del proceso: " id
		tmp_index=$(getIndex "$id" "${swp_proc_id[@]}")
		if [[ ! -z $tmp_index ]]; then 
			tmp_mem_index=$(getIndex "$id" "${proc_id[@]}")
			if [[ -z $tmp_mem_index ]]; then 
				proc_id+=("$id")
				proc_size+=("${swp_proc_size[$tmp_index]}")
				proc_time+=("${swp_proc_time[$tmp_index]}")
			fi
		fi
	elif [[ $REPLY -eq 2 ]]; then
		read -p "ID del proceso: " id
		tmp_mem_index=$(getIndex "$id" "${proc_id[@]}")
		if [[ ! -z $tmp_mem_index ]]; then 
			unset proc_id[$tmp_mem_index]
			unset proc_size[$tmp_mem_index]
			unset proc_time[$tmp_mem_index]
			proc_id=( "${proc_id[@]}" )
			proc_size=( "${proc_size[@]}" )
			proc_time=( "${proc_time[@]}" )
		fi
	elif [[ $REPLY -eq 3 ]]; then
		echo
	elif [[ $REPLY -eq 4 ]]; then
		echo
		procSort "${proc_time[@]}"
	fi
	
	REPLY=
	actualizarInterfaz
}

function getIndex() {
	local tmp_value="${1}"
    shift
    local tmp_array=("${@}")
	
	for i in "${!tmp_array[@]}"; do
	   if [[ "${tmp_array[$i]}" = "${tmp_value}" ]]; then
		   echo "${i}";
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
		pedirDatos 0
	else
		pedirDatos 1
	fi
else
	leerArgs "$@"
fi

proc_size=()
proc_id=()
proc_time=()

actualizarInterfaz
while true ; do step ; done
