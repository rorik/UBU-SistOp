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
		printf "      \e[48;5;17mTiempo: %3d\e[0m      \e[48;5;17mNúmero de Procesos: " "$tiempo"
		if [[ -z $proc_count_abreviacion ]]; then
			printf " %3d" "$proc_count_redondeado"
		else
			printf "%3d%1s" "$proc_count_round" "$proc_count_abreviacion"
		fi
		printf "\e[0m      \e[38;5;17m#\n"
		header 0
	fi
}

function pedirDatos() {
	if [ -z "$mem_tamano" ]; then #si el tamaño de memoria nulo
		until [[ $mem_tamano =~ ^[0-9]+$ ]] && [[ ! $mem_tamano -eq 0 ]]; do #hasta el tamaño de memoria empiece entre 0 y 9 Y sea diferente a 0 hacer...
			printf "\e[1A%80s\r" " " #imprimir 80 espacios en color 1A
			read -p "Tamaño (en bloques) de la memoria: " mem_tamano #te pide que escribas algo y eso eso va a ser el tamaño de memoria
			printf "\e[91mINTRODUCE UN NÚMERO SUPERIOR A 0\e[39m\r" #te muestra en pantalla el texto y vuelve a la linea anterior
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

			convertirDireccion $i "proc_paginas"
			proc_id[$i]="P${i}" #Si no tiene la id asignada le da una
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w) #Asigna el tiempo rastante al numero de paginas
			log 3 "    Proceso ${i}, con ID <${proc_id[$i]}>, Secuencia <${proc_paginas[$i]}>, Bloques <${proc_tamano[$i]}>, Llegada <${proc_tiempo_llegada[$i]}>"
		done
	fi

	tiempo_final="$(ultimoTiempo)"
}

function leerArgs() {
	while [ "$1" != "" ]; do #mientras el parametro 1 no sea un espacio hacer
		case $1 in
			-s|--silencio) #si el parametro es s o silencio
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
	IFS=$'\n'; set -f #Establece el valor de separacion como final de linea
	for line in $(<$filename); do
		line=$(echo $line | cut -d '#' -f1 | tr -d ' ' | tr -d '\r') #elimina los espacios (-d) y tr sustituye
		log 0 "    Linea leida <${line}>"
		if [[ ! $line =~ ^[+] ]] && [[ ! -z $line ]]; then #si la linea no empieza por # y + o no es nula entonces...
			log 0 "    Es proceso:"
			proc_tamano[$i]=$(echo $line | cut -d ';' -f1) #guarda el tamaño, porque va cortando todolo separado por ; y coge la 1ª columna(-f1)
			log 0 "      Tamaño <${proc_tamano[$i]}>"
			proc_paginas[$i]=$(echo $line | cut -d ';' -f2) #guarda las paginas
			log 0 "      Secuecia <${proc_paginas[$i]}>"
			proc_tiempo_llegada[$i]=$(echo $line | cut -d';' -f3) #guarda el tiempo de llegada
			log 0 "      Llegada <${proc_tiempo_llegada[$i]}>"
			proc_id[$i]=$(echo $line | cut -d';' -f4) #guarda la id
			log 0 "      ID <${proc_id[$i]}>"
			if [[ -z ${proc_id[$i]} ]]; then
				proc_id[$i]="P${i}" #si el proceso no tiene id se le asigna uno por defecto
				log 0 "      Nueva ID <${proc_id[$i]}>"
			fi
			convertirDireccion $i "proc_paginas"
			proc_tiempo_ejecucion[$i]=0
			proc_tiempo_ejecucion_restante[$i]=$(echo ${proc_paginas[$i]} | tr ',' ' ' | wc -w) #cuenta el numero de paginas y lo asigna al tiempo de ejecucion  restante
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
					"DIRECCIONES")
						proc_pagina_tamano=$(echo $line | cut -d ':' -f2)
						log 0 "        de sistema <${proc_pagina_tamano}>"
						log 3 "    Configuración, tamaño de pagina <${mem_sistema}> ";;
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

function convertirDireccion() {
	local index=$1
	local -n destino="$2"
	local -a direcciones=()
	local paginas=""
	IFS=',' read -r -a direcciones <<< "${destino[$index]}"
	destino[$index]=""
	for direccion in ${direcciones[@]}; do
		destino[$index]+="$(expr $direccion / $proc_pagina_tamano),"
	done
	destino[$index]=$(echo "${destino[$index]::-1}")
}

function actualizarInterfaz() {
	header 2
	printf "\e[38;5;17m#\e[39m     \e[4m%s\e[0m      \e[38;5;18m#\e[39m     \e[4m%s\e[0m     \e[38;5;18m~\e[39m   \e[4m%s\e[0m   \e[38;5;18m~\e[39m     \e[4m%s\e[0m      \e[38;5;17m#\e[39m\n" "SWP" "ID" "T. RESTANTE" "POSICIONES EN MEMORIA" #crea la cabecera de la tabla
	for i in {0..10}; do
		printf "\e[38;5;17m#\e[39m"
		if [[ ! -z ${swp_proc_id[$i]} ]]; then
			if [[ ${proc_tamano[${swp_proc_index[$i]}]} -lt 10 ]]; then
				printf "%9s (%d)" "${swp_proc_id[$i]:0:9}" "${proc_tamano[${swp_proc_index[$i]}]}"
			elif [[ ${proc_tamano[${swp_proc_index[$i]}]} -lt 100 ]]; then
				printf "%8s (%d)" "${swp_proc_id[$i]:0:8}" "${proc_tamano[${swp_proc_index[$i]}]}"
			else
				printf "%7s (>99)" "${swp_proc_id[$i]:0:7}" "${proc_tamano[${swp_proc_index[$i]}]}"
			fi
		else
			printf "%13s" " "
		fi
		printf " \e[38;5;18m#\e[39m "
		if [[ ! -z ${mem_proc_index[$i]} ]]; then
			printf "%10s \e[38;5;18m~\e[39m %5s%4d%6s \e[38;5;18m~\e[39m %-31s" "${mem_proc_id[$i]:0:10}" " " "${proc_tiempo_ejecucion_restante[${mem_proc_index[$i]}]}" " " "${mem_proc_posicion[${mem_proc_index[$i]}]:0:30}" #pone los datos en la tabla
		else
			printf "%10s \e[38;5;18m~\e[39m %15s \e[38;5;18m~\e[39m %31s" " " " " " " #si esta vacio solo pone el swap
		fi
		printf "\e[38;5;17m#\e[39m\n"
	done
	header 0
	printf "\e[38;5;17m#\e[39m "
	for i in {0..24}; do
		if [[ -z ${mem_paginas[$i]} ]]; then
			echo -ne "\e[32m ##" #imprime # en verde si esta vacia la pagina
		else
			printf "\e[31m %2d" "${mem_paginas_secuencia[${i}]}" #sino en rojo imprime la pagina
		fi
	done
	printf "  \e[38;5;17m#\e[39m\n"
	header 0
}

function step() {
	if [[ $tiempo -le $tiempo_final ]]; then
		poblarSwap $tiempo
	elif [[ ${#swp_proc_id[@]} -eq 0 ]]; then finalizarEjecucion 0; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then poblarMemoria; fi
	if [[ ${#mem_proc_id[@]} -eq 0 ]]; then
		if [[ ${proc_tamano[${swp_proc_index[0]}]} -gt $mem_tamano ]]; then finalizarEjecucion 20; fi
	else ejecucion; fi
	if [[ ! -z $evento ]]; then
		actualizarInterfaz
		echo ${evento::-2}
		unset evento
		read -p "Presiona cualquier tecla para continuar " -n 1 -r
	fi
	tiempo=$(expr $tiempo + 1)
}

function stepSilencio() {
	if [[ $tiempo -le $tiempo_final ]]; then
		poblarSwap $tiempo
	elif [[ ${#swp_proc_id[@]} -eq 0 ]]; then finalizarEjecucion 0; fi
	if [[ ! ${#swp_proc_id[@]} -eq 0 ]]; then poblarMemoria; fi
	if [[ ${#mem_proc_id[@]} -eq 0 ]]; then
		if [[ ${proc_tamano[${swp_proc_index[0]}]} -gt $mem_tamano ]]; then finalizarEjecucion 20; fi
	else ejecucion; fi
	unset evento
	tiempo=$(expr $tiempo + 1)
}

function notacionCientifica() {
	local i=1000
	local numero=$1 #primer argumento es el numero a redondear
	local -n redondeado="$2" #la variable donde se guardara la salida
	local -n abreviacion="$3" #la variable donde se guarda la abreviacion
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

function poblarSwap() {
	local tiempo=$1
	local i=0
	for (( i=0 ; i<"${#proc_id[@]}"; i++ )); do
		if [[ "${proc_tiempo_llegada[$i]}" -eq $tiempo ]]; then
			evento+="${proc_id[$i]} > SWAP, "
			swp_proc_id+=("${proc_id[$i]}")
			swp_proc_index+=("$i")
		fi
	done
}

function poblarMemoria() {
	mem_usada=${#mem_paginas[@]} #memoria usada es igual al numero de paginas
	local espacio_valido=1 #define variable local espacio valido igual a 1
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
						mem_proc_posicion[${swp_proc_index[0]}]="${mem_proc_posicion[${swp_proc_index[0]}]}$(expr $i + $j) " #en cada proceso guarda la posicion de sus paginas en memoria
					done
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
	fi
	if [[ -z $modo_silencio ]]; then
		unset mem_usada_redondeado
		notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
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
			if [[ ${mem_proc_index[$index_mem_objetivo]} = ${mem_paginas[$i]} ]]; then #si la id del proceso es igual a la id del que buscasa entonces...
				unset mem_paginas[$i] #saca procesos de la memoria si
			fi
		fi
	done
	i=0
	for index in ${mem_proc_index[@]}; do #por cada indice en memoria hacer...
		if [[ $index_objetivo -eq $index ]]; then #si lo encuentras entonces...
			evento+="${mem_proc_id[$i]} > OUT, "
			unset mem_proc_index[$i] #saca el indice de memoria
			unset mem_proc_id[$i] #saca el id de memoria
			for pos in ${mem_proc_posicion[$index_objetivo]}; do #por cada posicion del proceso hacer...
				unset mem_paginas_secuencia[$pos] #saca las paginas
			done
			unset mem_proc_tamano[$i] #saca el proceso de tamaño de la memoria
			unset mem_proc_posicion[$i] #saca el proceso de posicion de la memoria
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

function posicionProcesos() {
	for ((i=0; i<=$mem_tamano; i++)); do
		if [[ ! -z ${mem_paginas[$i]} ]]; then
			echo "<<TODO>>"
		fi
	done
}

function defragmentarMemoria() {
	local pivot=-1
	local pivot_final=0
	local count=0
	for ((i=$mem_tamano ; i>0 ; i-- )); do #cuenta lso procesos vacios a la derecha
		if [[ -z ${mem_paginas[$i]} ]]; then
			if [[ $pivot -gt 0 ]]; then ((count++)); fi
		else
			if [[ $pivot -lt 0 ]]; then pivot_final=$i; fi
			pivot=$i
		fi
	done
	for ((i=0 ; j<=$count ; j++ )); do # por cada hueco hace...
		for ((i=0 ; i<=$pivot_final ; i++ )); do #por cada proceso comprueba si hay un hueco a la izquierda
			if [[ -z ${mem_paginas[$i]} ]] && [[ ! -z ${mem_paginas[$(expr $i + 1)]} ]]; then #si hay hueco se mueve
				mem_paginas[$i]=${mem_paginas[$(expr $i + 1)]}
				mem_paginas_secuencia[$i]=${mem_paginas_secuencia[$(expr $i + 1)]}
				unset mem_paginas[$(expr $i + 1)]
				unset mem_paginas_secuencia[$(expr $i + 1)]
			fi
		done
	done
	evento+="DEFRAG, "
}

function ejecucion() {
	local min=${proc_tiempo_ejecucion_restante[${mem_proc_index[0]}]}
	local min_i=${mem_proc_index[0]}
	min_mem_index=0
	local i=0
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
	#actualizarPaginas $min_i
	if [[ ${proc_tiempo_ejecucion_restante[$min_i]} -eq 0 ]]; then
		eliminarMemoria $min_i $min_mem_index
	fi
}

function actualizarPaginas() {
	local index=$1
	echo "TODO"
	read -n 1
}

function ultimoTiempo() {
	local tiempo_max=0
	for tiempo in "${proc_tiempo_llegada[@]}"; do
		if [[ $tiempo -gt $tiempo_max ]]; then tiempo_max=$tiempo; fi #coge el tiempo de llegada maximo de todos los tiempos
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

declare -a mem_paginas=() #crea un array
declare -i mem_usada=0 #declara un int

if [ $# -eq 0 ]; then #si no hay argumentos entonces...
	header 1 ; header 0
	log 5 'No Argumentos, comprobando modo de introduccion de datos:'
	read -p 'Introducción de datos por archivo (s/n): ' -n 1 -r ; echo
	log 0 "  RESPUESTA INPUT: $REPLY"
	if [[ $REPLY =~ ^[SsYy]$ ]]; then #si la respuesta es S
		read -p 'Nombre del archivo: ' filename
		log 5 "  Por archivo (${filename})"
		leerArchivo
	else log 5 '  Por teclado';	fi
elif [[ -z $modo_silencio ]]; then header 1 ; header 0; fi #en caso de que sea en modo silencioso entonces...

pedirDatos
tiempo=-1
if [[ -z $modo_silencio ]]; then #si no es modo silecioso
	notacionCientifica $mem_tamano "mem_tamano_redondeado" "mem_tamano_abreviacion" #abrevia la memoria
	notacionCientifica $mem_usada "mem_usada_redondeado" "mem_usada_abreviacion"
	notacionCientifica $proc_count "proc_count_redondeado" "proc_count_abreviacion"
	while true ; do step ; done
else
	while true ; do stepSilencio ; done #loop infinito de pasos sin interfaz grafica
fi
