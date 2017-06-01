# UBU-SistOp
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](srpt.sh)
[![Release](https://img.shields.io/badge/release-v1.1-blue.svg)](https://github.com/rorik/UBU-SistOp/releases/latest)

### Ejecución
Para una correcta ejecución y visualización del programa, se recomienda usar konsole, u otro terminal compatible con colores de 8 bits. Así como una versión de bash actualizada (>=4.3).

Para ejecutar el programa, podemos hacer lo siguiente:
1. #### Ejecución directa
    * ##### Dar permisos de ejecución:
    ```shell
      chmod +x srpt.sh 
    ```
    * ##### Ejecutar
    ```shell
      ./srpt.sh [argumentos]
    ```
2. #### Asignar alias
    * ##### Guardar alias:
    
        Añadir la siguiente linea al archivo .bashrc en el directorio home del usuario (Sustituir los valores entre corchetes)
    ```shell
      alias [nombre]="bash /[directorio]/srpt.sh"
    ```
          Ejemplo:
    ```shell
      alias srpt="bash /home/juan/descargas/srpt.sh"
    ```
    * ##### Ejecutar
    ```shell
      [nombre añadido en el paso anterior] [argumentos]
    ```
          Ejemplo:
    ```shell
      srpt -f input.txt
    ```
3. #### Ejecución bash
    ```shell
      bash srpt.sh [argumentos]
    ```


### Uso
Se recomienda la ejecución del programa a partir de un archivo.

#### Argumentos:
  * ##### -b  [TIEMPO]
    Habilita modo debug en TIEMPO
  * ##### -d
    Habilita modo debug y nivel de log 0
  * ##### -f  [FILENAME]
    Cargar datos desde FILENAME
  * ##### -l  [NIVEL]
  	Nivel de salida por fichero (0 debug, 1 extendido, 2 estructural, 3 por defecto, 4 alertas, 5 mínimo, 9 ejecición, 10 deshabilitado)
  * ##### -m	[BLOQUES]
    Tamaño de memoria en bloques
  * ##### -p	[NÚMERO]
    Número de procesos
  * ##### -s
    Deshabilita salida por pantalla
  * ##### -u [TIEMPO]
    Deshabilita modo debug en TIEMPO

#### Ejemplo de uso:
```shell
  bash srpt.sh -f input.txt -m 12 -l 9 -s -b 45 -u 60
  bash srpt.sh -p 20 -m 25
  bash srpt.sh -d -f /home/pepe/entradaSRPT.xml
```

### Archivo de entrada
Este archivo debe tener un formato específico. Todos los espacios son ignorados. Para comentar una linea insertar una almohadilla al principio '#', tambien se puede comentar con '#' al final de una linea.
#### Lineas de configuración:
Se utilizan para establecer configuraciones de ejecución.
```
  +MEMORIA: 300
  +DIRECCIONES: 125
```
Empiezan por un '+', seguido por el nombre de la configuración ('MEMORIA' o 'DIRECCIONES'), dos puntos ':', y por último el valor a ser establecido.
#### Lineas de procesos:
Sirven para configurar un nuevo proceso.
```
  3 ; 98, 131, 222, 341, 400, 599, 674, 765 ; 0 ; nano
  2 ; 7623, 1337, 3301 ; 0 ; top
  6 ; 2, 15, 825, 725, 1925, 2275, 425, 390, 330, 290, 770, 910, 170, 156, 132, 116, 308, 364, 68, 4 ; 1
  5 ; 2279, 6823, 7023, 4035, 9586, 8002, 8514, 957, 8796, 9206 ; 3
```
Consisten de 3 o 4 argumentos separados por punto y coma ';'.
* El primer argumento es el número de marcos de página que el proceso ocupará en memoria
* El segundo es la secuencia de direcciones a ejecutar separados por comas
* El tercero es el tiempo en el que llegará el proceso
* El cuarto es opcional, y da un nombre (id) al proceso, en caso de no ser dado, se le da una id genérica (P0,P1,P2,...)
