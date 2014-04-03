#ifndef __HASH_C
#define __HASH_C

#include <stdlib.h>
#include <string.h>
#include "hash.h"

/* The default increment when expanding the hash table. */
#define DEFAULT_INCREMENT  50

/* Set the maximum allowed load factor (80% suggested by Loudon) */
#define MAX_ALLOWED_LOAD_FACTOR  .80

static int hash_expand(hash_t *hash);

/***********************************************************************
 * Allocates, initializes, and returns a hash container. This function
 * should be used to create hash tables. This function will allocate
 * the hash table on the heap, thus, it must be properly destroyed with
 * heap_destroy() to free all resources (otherwise memory leaks will
 * occur).
 *
 * All elements stored in the hash table must be able to be used to
 * calculate a hash value based on the given 'hash' function.
 * 
 * Parameters:
 *   hash: This is the function used to calculate the hash value of a
 *     any particular key stored in this hash.
 *   compare: A comparison function used to compare keys. The comparison
 *     function must return an integer less than, equal to, or greater
 *     than zero if 'left' is found, respectively, to be less than,
 *     equal, or greater than 'right'.
 *   kdestroy: A function used to deallocate a key from memory. This
 *     function may be the standard free(3) function or a user-defined
 *     function of the same prototype.
 *   vdestroy: A function used to deallocate a value from memory. This
 *     function may be the standard free(3) function or a user-defined
 *     function of the same prototype.
 *   inc: The default number of elements to increment the hash table by
 *     when the hash table fills up. If 0 is specified, the default will
 *     be DEFAULT_INCREMENT. This only takes effect when expanding the
 *     hash table after it has been initialized and has filled up its
 *     default size.
 *
 * Return Value:
 *   Returns a pointer to a 'hash_t' that represents a hash table. On
 *   error, this returns NULL (most likely an error in memory
 *   allocation).
 **********************************************************************/
hash_t *hash_create(unsigned int (*hash_code)(const void *key),
		int (*compare)(const void *left, const void *right),
		void (*kdestroy)(void *key), void (*vdestroy)(void *key), int inc)
{
	int bsize;
	hash_t *hash;

	if ((hash = malloc(sizeof(hash_t))) == NULL)
		return NULL;

	hash->length = DEFAULT_INCREMENT;
	bsize = hash->length * sizeof(hash_node_t);
	if ((hash->table = malloc(bsize)) == NULL) {
		free(hash);
		return NULL;
	}
	/* FIXME: This should be redundant. Remove??? */
	memset(hash->table, 0, bsize);

	hash->size = 0;
	if (inc <= 0)
		hash->increment = DEFAULT_INCREMENT;
	else
		hash->increment = inc;
	hash->hash_code = hash_code;
	hash->compare = compare;
	hash->kdestroy = kdestroy;
	hash->vdestroy = vdestroy;

	return hash;
}

/***********************************************************************
 * Destroys all elements in the hash table and de-allocates the hash
 * container. This function is the converse of 'hash_create()' and
 * should be used to destroy all hash tables allocated with
 * 'hash_create()', even if the hash table is empty.
 *
 * NULL 'hash' containers are explicitly checked for, so it is safe to
 * pass NULL to this function.
 *
 * Parameters:
 *   hash: The hash to destroy.
 *
 * Return Value:
 *   No return value.
 **********************************************************************/
void hash_destroy(hash_t *hash)
{
	if (hash == NULL)
		return;

	int i;
	for (i = 0; i < hash->length; i++) {
		if (hash->table[i].key != NULL && hash->kdestroy != NULL)
			hash->kdestroy(hash->table[i].key);
		if (hash->table[i].value != NULL && hash->vdestroy != NULL)
			hash->vdestroy(hash->table[i].value);
	}
	free(hash->table);
	free(hash);
	hash = NULL;
}

/***********************************************************************
 * Inserts a 'key' and 'value' pair into the given 'hash' table.
 *
 * NULL parametrs are explicitly checked for, so it is safe to pass NULL
 * parameters to this function and have it have no effect.
 *
 * Parameters:
 *   hash: The hash table to insert the key and value into.
 *   key: The key of the element to insert.
 *   value: The value of the element to insert.
 *
 * Return Value:
 *   Returns 0 on success; -1 on error.
 **********************************************************************/
int hash_insert(hash_t *hash, const void *key, const void *value)
{
	if (hash == NULL || key == NULL)
		return -1;

	int position, i;

	/* Check to see if the hash table needs to be expanded. */
	if (hash_load_factor(hash) >= MAX_ALLOWED_LOAD_FACTOR &&
	    hash_expand(hash) == -1)
		return -1;  /* Unable to expand hast table. */

	/* Search for an open position--one is guaranteed to exist. */
	for (i = 0; i < hash->length; i++) {
		position = (hash->hash_code(key) + i) % hash->length;
		if (hash->table[position].key == NULL) {
			hash->table[position].key = (void *)key;
			hash->table[position].value = (void *)value;
			hash->size++;
			return 0;
		}
	}

	/* Should never see the end of this function. */
	return -1;
}

/***********************************************************************
 * An internal function to expand the hash table heap.
 *
 * NULL is explicitly checked for as a parameter, and no action is taken
 * if the parameter is NULL.
 *
 * Parameters:
 *   hash: The hash table to expand.
 *
 * Return Value:
 *   Retruns 0 on success or -1 on error.
 **********************************************************************/
static int hash_expand(hash_t *hash)
{
	if (hash == NULL)
		return -1;

	int bsize;
	hash_node_t *n;

	bsize = (hash->length + hash->increment) * sizeof(hash_node_t);
	if ((n = malloc(bsize)) == NULL)
		return -1;
	memset(n, 0, bsize);
	memcpy(n, hash->table, hash->length * sizeof(hash_node_t));
	free(hash->table);
	hash->table = n;
	hash->length += hash->increment;

	return 0;
}

/***********************************************************************
 * Searches for the element that corresponds to the given 'key'. The
 * action taken when/if the element is found is defined by the 'type'
 * parameter, and should be one of the following:
 *   1) HASH_VALUE - Returns the value associated with the given key.
 *   2) HASH_EXISTS - Returns the key if it exists in the hash table.
 *   3) HASH_DELETE - Deletes the element associated with the given key.
 *
 * This function is best used through the 'hash_value()', hash_exists(),
 * and 'hash_delete()' macros.
 *
 * This function explicitly checks for NULL parameters, so it is safe to
 * pass NULL and have this function have no effect.
 *
 * Parameters:
 *   hash: The hash table to search for the given key value pair.
 *   key: The key used to look up the desired value.
 *   value: The value defines the action to be taken when/if the element
 *     is found. Possible values include:
 *       * HASH_VALUE - Returns the value of the given key. 
 *       * HASH_EXISTS - Returns a reference to the given key if it
 *         exists in the hash table.
 *       * HASH_DELETE - Deletes the element of the given key.
 *
 * Return Value:
 *   Returns the value associated with the given 'key' or NULL if no key
 *   exists in the hash table.
 **********************************************************************/
void *hash_search(hash_t *hash, const void *key, int type)
{
	if (hash == NULL || key == NULL)
		return NULL;

	int position, i;

	for (i = 0; i < hash->length; i++) {
		position = (hash->hash_code(key) + i) % hash->length;
		if (hash->table[position].key != NULL &&
		    hash->compare(key, hash->table[position].key) == 0) {
			switch (type) {
				case HASH_VALUE:
					return hash->table[position].value;
				case HASH_EXISTS:
					return hash->table[position].key;
				case HASH_DELETE:
					if (hash->table[i].key != NULL && hash->kdestroy != NULL)
						hash->kdestroy(hash->table[position].key);
					if (hash->table[position].value != NULL && hash->vdestroy != NULL)
						hash->vdestroy(hash->table[position].value);
					hash->table[position].key = NULL;
					hash->table[position].value = NULL;
					hash->size--;
					return NULL;
			}
		}
	}

	/* The search failed if this is reached, return error code. */
	return NULL;
}

#endif
