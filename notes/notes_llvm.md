## shadow call stack
implémenation dans clang mais qui marche qu'avec aarch64 pour l'instant 
**on peut ptetre utiliser leur parser au moins pour detecter ou faire les modifs et ajouter les bonnes instructions de modif de la SS**

* ca implémente du stack canary classique -> ptetre voire si ya dautres techniques pour proteger d'un dépassement de mémoire

LLVM implémente deja des schéma pour une SS -> SCS shadow call stack 
https://source.android.com/docs/security/test/shadow-call-stack

**On travaille sur GCC donc ca peut etre interessant mais pas vrm notre cas MDR**