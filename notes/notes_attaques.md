# notes sur les attaques 
il y a 10 scenar d'attaques de dispo, il faut essayer de se proteger du max du nb de scénarios 
les scenario sont définient dans le main du rip\_attack\_generator.c avec le controle sur la constante ATTACK\_NR

il y a 5 parametres qui définissent chaque scénarios: 
* la technique : est ce qu'on utilise le premier pointeur directmeent ou on inject les trucs grace au deuxieme pointeur utilisé ?
    * direct :
    * indirect :
* parametre injecté : 
    * ROP : return to LIBC mais chainé
    * return to LIBC : on va créer une stack qui va return vers une partie de la libc qui nous interesse, puis on va mettre dans la suite des argument les trucs qui nous interesse dans le call, vrm comme si on faisait un call au final
    * data  
    * injected code
* attack location :
    * stack 
    * heap
* code ptr : 
    * ret addr, 
    * 
* function that is used to attack :
    * sprintf, memcpy, homebrew


solution known for the different attacks : 
    * ROP : shadow stack, branch recording units, ROP guards, ROP pecker, triggers(new page access, access violation), 
    (https://www.intel.com/content/dam/develop/external/us/en/documents/catc17-anti-rop-moving-target-defense-844137.pdf)
    * return to libc : aslr(peu efficace sur du 32b psk seul 16b randoms), detection de corrution de pile, chargement de libc avec add avec un byte a 0x00 mais peut etre contourné
    * data : les canary
    * injected code : NX, les canary


### SoK: Shining Light on Shadow Stacks IEEE conference (https://www.youtube.com/watch?v=v5E0gTOAe7Q)
shadow stack : on a une deuxieme stack qui est crée de facon dynamique a coté de la stack classique qui contient la valeur a laquelle ont doit return. dés qu'on a un return, on compare la valeur sur la stack a laquelle on est sencé retourner et celle qui est sur la shadow stack et si c pas la meme on terminate le programme. 
Il y a 2 implémentation possible pour la SS : 
    * indirect mapping : pour chaque call on va push l'adresse de retour dans la shadow stack et la stack classique -> et lors du return on fait 2 pop en meme temps. -> on est donc econome en espace mémoire mais la translation peut prendre un peu de temps 
    * direct mapping : on fait une copie dans un espace de meme taille que la stack classique donc on va prendre moins de temps a la converssion mais plus d'espace.
* IEEE recomands indirect
* general purpose register est recommandé detre utilisé 

**faire attention il faudra utiliser le PMP dessus et savoir ou la mettre**
* key point : shadow stack + control flow integrity = practical control flow hijack mitigation

### Work in progress: A formally verified shadow stack for RISC-V (papier de guillaume hiet)
il peut y avoir des intégration materiel et software de la shadow stack.
software ca permet de pas avoir a etre dépendant de la plateforme 
hardware ca permet de pas a avoir a modifier le code

si on a pas d'OS pour gérer ca on a 2 techniques une fois qu'on a detecté qu'il y a une merde dans le control flow 
    * on close l'execution et on casse tout
    * on utilise l'addresse donné dans la shadow stack sans les arguments pour le return -> gros downside -> dés qu'on detecte un dépassement normalement on devrait interdire la fin de l'execution psk c pas légale dans l'ISA et on peut pas faire confiance dans le reste de la stack qui suit.

Like stack canaries, shadow stacks do not protect stack data other than return addresses, and so offer incomplete protection against security vulnerabilities that result from memory safety errors. 


Premier pb dans la config de test se fait lorsque l'on veut tester le setup avec le cv32a6\_zybo sur qemu 
    1. permet pas l'emulation
    2. le debbugage est sencé marché mais il fonctionne ps chez moi mais si l'émulation marche ps jvois ps comment le debug pourrait marcher ???!!??
 
