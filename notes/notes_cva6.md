CVA6 -> 6 stages pipeline 

# Introduction

purpose : run OS at reasonable speed 
le scoreboard est la pour cacher les latence en lancant les instructions qui ne dépendent pas des données

inst ram(L1 inst cache) -> 1 clk lat
data ram(L1 data cache) -> 3 clk lat

CSR : Control and Status registers -> listes de registres qui contient pleins d'infos differentes sur l'état du CPU, sur le CPU en général(vendeur et implémentation...), les trap handlers, la mem protection ... compteur de cycle, mode de débug

# PC generation

BTB : branch target buffer 

BHT : branch history table

si le BTB décode un PC comme un jump, le BHT décide si la branche est prise ou non, cela est séparé en 2 étape de la pipeline.
Le PC gen communique avec le IF(instruction fetch) a travers un signal de handshake. 

PC gen -> generateur du prochain PC
les cources du prochain PC peuvent etre : 
#### assignement par défaut : PC + 4
#### prédiction de branche :  si BHT et BTB prédisent une branche alors ils en informe IF puis setup le prochain PC 
On a 2 structures qui sont passés dans la pipeline branchpredict_sbe_t qui contient les informations de la brnache et bp_resolve_t qui contient les infos sur la prédiction de branche. Cela permet la correction des erreurs de branche
### modification du control flow due a une erreur de prédiction 
### return d'un call d'environement : retour à l'addresse stoqué dans epc
### exception/interrupt : (user mode exception non supportés) : 
but du CSR est de définir où trap et présenter adresse ok a pcgen
### pipeline flush (CSR side effect) : 
quand on ecrit dans un CSR on reprend la pipeline de 0 pour prendre en compte les modifs dans le CRS
### debug 

## Branch prediction 
* si on est en 16b, la branch prediction marche pas mais il est rare d'utiliser des branches en 16b donc en réalité y'a peu de conséquences

decoder : first stage of the backend
compressed instructions peuvent désaligner les instructions car elles sont sur 16. On peut donc avoir des instructions de 32 qui sont entre 2 de 16 et ducoups sont aligné sur du 16 mais font 32. On va les réaligner pour que ca match bien. Les insts de 16 sont placé en MSB d'un word de 32.

le compressed decoder va décompresser les instruction de 16 pour les étendre sur 32.
Le décodeur va transformer l'instruction en un set d'info pour le scoreboard, on donne un index a chaque instruciton pour qu'elle soit reconnu en fin d'exec et que l'on arrive a la réarenger dans le bon sens.

Issue stage recoit l'instruction décodé et la lance dans les bons blocs fonctionnels.
le issue contient aussi tous les differents registres CPU.
le issue coordonne ducoups les inst -> quand on execute une inst de mult qui prend n clock cycle et apres une alu qui prend 1, que la alu sorte pas avant la mult. il faut donc temporisé la sortie.
le scoreboard est une fifo avec un read et un write et un ack ainsi que des signaux qui indiquent ce qui va etre modifié par l'inst qui suit.

l'execute stage a plusieurs blocs foncitonel : ALU, branch unit, load store unit(LSU), CSR buffer et multiply/divide.

ALU : 32/64 bits sub, add, shift, comp in always 1clk
branch unit : cond jmp, uncond jmp -> control flow -> decides if branch mispredicted -> correct PC stage-> correct BHT => 1 clk
LSU : interface to the slow SRAM, LSU bypass : gives LSU status, load unit : loads data in mem -> checks store buffer for not commited mem change. store units : manages stores, store buffer : stores all stores : 2 buff one for already stores and another for outstandinf instructions -> speculative. MMU(memory address translation et mem access) -> priorise instr add to data add, page table walker (PTW, rable walks et si ya une erreur, il throw une page fault exception)

mult : 2 clk, div (serial div): can take up to 64 clk
CSR buffer : stores add of the CSR reg because CSR modifies architectural state -> status reg. On peut modifier le status que quand l'info a été commit c'est pour ca qu'on a besoin d'un acces aussi proche du coeur.

commit : ca va ecrire les modif CSR, ca va faire le fetch de toutes les sources d'exceptions. Dans le cas ou on a plusieurs

** questions : dans le cas ou on a plusieurs exceptions qui arrivent au meme clk de differentes stages au commit du CPU est ce qu'on a une priorisation d'une exception par rapport a une autre et ducoup ignore une exception ? dans ce cas est ce qu'on pourrait pas faire passer une branch prediction error pour rien et faire de la merde dans le program ??


**la LSU est un peu complexe peut etre la revoire a tete reposé demander des précisions sur le role de PTW, DTLB et D$ psk r comprit

RIPE Attack :

948 buffer overflows -> on tsack, heap, data et bss
4 attack code : return int to libc, nonop, rop, dataonly


equipe OS peut se concentrer a corriger ca déja ? :
vulns : memcpy, homebrew(memcpy equivalent), str(n)cpy, str(n)cat, s(n)printf, sscanf(format string)
RSP :on peut pas changer les progs executés donc ca sert a rien. voire si on a le droit de changer les lib dynamique


zephyr OS :
solution psk linux est trop gros, a été certifié

features : multithreading, interrupt service, mem alloca, inter thread sync, inter thread data passing service, power management, dev tree support
mem protection : stack overflow prot, kernle object et device permission tracker, thread isoation,


*** est ce que le watchdog est implémenté dans le riscV ? -> zephyr implémente l'option de watchdog -> peut etre un début d'implémentation de sécu mais plus niveau archi log ducoups psk ca empeche juste detre en softlock





