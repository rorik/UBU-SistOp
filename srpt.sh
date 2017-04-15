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
		if [ -z "$proc_size" ]; then
			for i in $(seq 1 $proc_count); do
				until [[ ${proc_size[$i]} =~ ^[0-9]+$ ]] && [[ ! ${proc_size[$i]} -eq 0 ]]; do
					read -p "[${i}] Bloques: " proc_size[$i]
				done
				until [[ ${proc_time[$i]} =~ ^[0-9]+$ ]] && [[ ! ${proc_time[$i]} -eq 0 ]]; do
					read -p "[${i}] Tiempo: " proc_time[$i]
				done
			done
		fi
	else
		until [[ $mem_size =~ ^[0-9]+$ ]] && [[ ! $mem_size -eq 0 ]]; do
			read -p "Tamaño (en bloques) de la memoria: " mem_size
		done
		until [[ $proc_count =~ ^[0-9]+$ ]] && [[ ! $proc_count -eq 0 ]]; do
			read -p "Número de procesos: " proc_count
		done
		for i in $(seq 1 $proc_count); do
			until [[ ${proc_size[$i]} =~ ^[0-9]+$ ]] && [[ ! ${proc_size[$i]} -eq 0 ]]; do
				read -p "[${i}] Bloques: " proc_size[$i]
			done
			until [[ ${proc_time[$i]} =~ ^[0-9]+$ ]] && [[ ! ${proc_time[$i]} -eq 0 ]]; do
				read -p "[${i}] Tiempo: " proc_time[$i]
			done
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
		echo "File not found"
		exit 1
	fi
	i=0
	while IFS=, read line val; do
		if [[ ! $line =~ ^[#+] ]]; then
			proc_size[$i]="${line//[[:blank:]]/}"
			proc_time[$i]="$(echo $val | tr -d '\r')"
			((i++))
		else
			if [[ $line =~ ^[+] ]]; then
				mem_size=$(echo $val | tr -d '\r')
			fi
		fi
	done < $filename
	if [ ! $i -eq 0 ]; then
		proc_count=$i
	fi
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

header 0
echo -e "           \e[48;5;17mBloques Utilizables de Memoria: $mem_size , Número de Procesos: $proc_count\e[0m"
header 1
