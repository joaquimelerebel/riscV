# Integrating RISC-V PMP Support in Zephyr, Kevin Hilman, Baylibre
goal : utilisation de threads dans le user space 

* zephyr a 2 modes : kernel et user -> support hardware peut marché quand meme.
* pour que chaque utilisateurs n'accedent pas aux autres espaces memoire, il faut de la protection physique
* chaque thread a sa propre stack pour que chaque thread puisse pas acceder aux autres stacks -> il y a une protection HW pour ca mais il y a aussi des implémentation software avec les stack canaries.
* memory domains : threads auront uniquement acces aux espaces minimum avec lequel ils peuvent foncitonnner. (.text, .data, stack) peut etre définit a build time ou a run time en dynamique 

## interesting riscV features 
* multiple modes : M (machine) mode (zephyr kernel will run there) -> full priviledge mode and U (user)mode (zephyr user theads)
* ECALL -> trap to change between M and U mode 
* PMP (physical memory protection) (optional)(**check if it exists on the implementation**)
    * check user memory access -> trap/catch if threads accesses wrongly the memory spaces
    * PMP : limited : 16 regions/entry
        * but often 8 regions max -> very small space !!
        * PMP entry : 8bit config reg (permission and access type) and a 32/64b add 
            * for 1 region need to use 2 PMP entry -> start add and end add
            * if mem space is natural power of 2 -> can get by with only 1 PMP entry -> must maximise the 2^n spaces width
    * on va avoir a protéger le .text, .data et le thread stack(comprenant .data) et le is\_user(définit le current mode du CPU) pour chaque thread -> minimum 5 PMP entry ducoups. 
    * quand on fait de la shared mem -> on utilise encore les PMPs  
    * par défaut on a le PMP qui fait une alloc a la puissance de 2 pour les PMP dans zephyr
    * HW stack protection -> on ajoute un stack guard grace a des PMP. Mais elles rentrent pas en conflit avec le user space psk c mit en place par le kernel. ?? **ps comprit pq ca aurait été un pb** 
    * ca complexifie pas mal mtn psk zephyr est vachement configurable et on peut choisir si on veut la CONFIG\_HW\_STACK\_PROTECTION
    * le riscV PMP emmulation does not work really well 
    
    * le nb de PMP est un générique dans la config HW -> zephyr permet la modification par un simple #define PMP\_MAX 
        
#  Using the RISC-V PMP with an Embedded RTOS to Achieve Process Separation and Isolation
* les registres de PMP sont dans les CSR -> chaque process a une process table -> 16 PMP pour chaque process
* on donne l'acces au code a chaque task et la meme heap, et process variable, toutefois, on donne pas le meme stack pour chaque task et on met une séparation physique entre chaque task qui permet la detection des stack overflows-> RedZone 
* on essaye de catch si on fait une ecriture dans la redzone pour voire sil y a eu un stack overflow 
* a chaque context switch il faut faire un chargement des nouvelles valeurs de tables de process 
* les process tables appartients au kernel c donc en mode machine 
* machine mode handler -> RTOS API pour que l'utilisateur fasse une requete sur le RTOS -> grab a mutex, IPC ... permet donc une com entre user mode and kernel mode
* quand on détecte une faute, un RTOS devrait normalement il y a handler qui permet au dev de choisir ce qu'il veut faire.

**peut etre faire une implémentation physique de la detection d'ecriture entre les differentes task ?**
**déja répondu dans la vidéo plus haut -> utilisation de PMP pour bloquer juste l'acces**

# Trusted Execution Environments: A Technical Overview of Intel SGX, Arm TrustZone, and RISC-V PMP 
* un des sujets de recherche en cours sur les PMP est 
    * le Smode PMP 
    * IO PMP -> physical memory from all memoty master


# Documentation zephyr 

* CONFIG\_HW\_STACK\_PROTECTION is an optional feature which detects stack buffer overflows when the system is running in **supervisor mode**. [...] Use compiler-assisted CONFIG\_STACK\_CANARIES for stack frames.



# modification de la compilation zephyr 
* On peut modifier le code zephyr a partir du fichier de config zephyr qui sont les prj.conf 
* Dans les fichiers Kconfig y'a les differentes options de configuration du zephyr 
* ces fichiers sont dans le repo dockerzephyr/zephyr/... 

