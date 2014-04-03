#ifndef __HASH_H
#define __HASH_H

typedef struct hash_node_t {
	void *key;
	void *value;
} hash_node_t;

typedef struct hash_t {
	int size;    /* The number of used entries in the hash. */
	int length;  /* The maximum number of entries possible in the hash. */
	int increment;  /* User defined increment step when table is full. */
	hash_node_t *table;
	unsigned int (*hash_code)(const void *key);
	int (*compare)(const void *left, const void *right);
	void (*kdestroy)(void *key);
	void (*vdestroy)(void *key);
} hash_t;

hash_t  *hash_create(unsigned int (*hash_code)(const void *key),
		int (*compare)(const void *left, const void *right),
		void (*kdestroy)(void *key), void (*vdestroy)(void *key), int inc);
void     hash_destroy(hash_t *hash);
int      hash_insert(hash_t *hash, const void *key, const void *value);
void    *hash_search(hash_t *hash, const void *key, int type);
double   hash_load_factor(hash_t *hash);

#define HASH_VALUE   0
#define HASH_DELETE  1
#define HASH_EXISTS  2

#define  hash_size(hash)           ((hash)->size)
#define  hash_is_empty(hash)       (!(hash)->size)
#define  hash_value(hash, key)     (hash_search(hash, key, HASH_VALUE))
#define  hash_exists(hash, key)    (hash_search(hash, key, HASH_EXISTS))
#define  hash_delete(hash, key)    (hash_search(hash, key, HASH_DELETE))
#define  hash_load_factor(hash) \
	(((double)(hash)->size / (double)(hash)->length))
#define  hash_probe_estimate(hash) (1 / (1 - hash_load_factor(hash)))

#endif
