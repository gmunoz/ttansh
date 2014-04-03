#ifndef SYMTAB_H
#define SYMTAB_H

#include "hash.h"

#define hash_t symtab_t

struct symtab_t *symlook(char *word);

#endif
