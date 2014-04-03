#ifndef _LIST_C
#define _LIST_C

#include <stdlib.h>
#include "list.h"

/* Static (private) function prototypes for this data structure */
static inline list_node_t *create_node(void *key);
static inline void destroy_node(list_t *list, list_node_t *node);

/***********************************************************************
 * Allocates, initializes, and returns a list container. Time
 * complexity is O(1).
 *
 * Parameters:
 *   destroy: A function of a specific prototype that may be applied to
 *     the keys of this list to deallocate from memory.
 *
 * Return Value:
 *   Returns a pointer to a list list structure, or NULL on error (most
 *   likely an error in memory allocation).
 **********************************************************************/
list_t *list_create(void (*destroy)(void *key))
{
	list_t *list;
	if ((list = malloc(sizeof(list_t))) == NULL)
		return NULL;

	if ((list->nil = malloc(sizeof(list_t))) == NULL) {
		free(list);
		return NULL;
	}

	list->size = 0;
	list->nil->next = list_nil(list);
	list->nil->prev = list_nil(list);
	list->destroy = destroy;

	return list;
}

/***********************************************************************
 * Destroys all elements in the list, including the list container. This
 * function uses the list_foreach_safe() function that is safe for
 * removal of elements. NULL lists are explicitly checked for, so it is
 * safe to pass a NULL list as a parameter. If the list head is NULL,
 * then it is assumed that the list is empty, and only the list
 * container needs to be freed. Once the list elements are freed, then
 * the list container is freed and it is explicitly re-set to NULL, so
 * the list parameter will equal NULL on success. Time complexity is
 * O(n).
 *
 * Parameters:
 *   list: The list to destroy.
 *
 * Return value:
 *   No return value.
 **********************************************************************/
void list_destroy(list_t *list)
{
	if (list == NULL)
		return;

	list_node_t *node, *lahead;
	list_foreach_safe(list, node, lahead) {
		destroy_node(list, node);
	}
	free(list_nil(list));
	free(list);
}

/***********************************************************************
 * Inserts a node (created by 'key') into the head of the given 'list'.
 * It is save to pass NULL in for any of the parameters, as they are 
 * explicitly checked. The run-time complexity is O(1).
 *
 * Parameters:
 *   list: The list to insert the 'node'.
 *   key: The key used to create a list node from and insert into the
 *       list.
 *
 * Return value:
 *   Returns 0 on success or -1 on error. Errors may occur if any invalid
 *   (NULL) parameters are passed in.
 **********************************************************************/
int list_insert(list_t *list, void *key)
{
	if (list == NULL || key == NULL)
		return -1;

	list_node_t *node;
	if ((node = create_node(key)) == NULL)
		return -1;

	list_next(node) = list_next(list_nil(list));
	list_prev(list_next(list_nil(list))) = node;
	list_next(list_nil(list)) = node;
	list_prev(node) = list_nil(list);
	list_size(list)++;

	return 0;
}

/***********************************************************************
 * Inserts a node (created by 'key') into the tail of the given 'list'.
 * It is save to pass NULL in for any of the parameters, as they are 
 * explicitly checked. The run-time complexity is O(1).
 *
 * Parameters:
 *   list: The list to insert the 'node'.
 *   key: The key used to create a list node from and insert into the
 *       list.
 *
 * Return value:
 *   Returns 0 on success or -1 on error. Errors may occur if any invalid
 *   (NULL) parameters are passed in.
 **********************************************************************/
int list_push(list_t *list, void *key)
{
	if (list == NULL || key == NULL)
		return -1;

	list_node_t *node;
	if ((node = create_node(key)) == NULL)
		return -1;

	list_prev(node) = list_prev(list_nil(list));
	list_next(list_prev(list_nil(list))) = node;
	list_prev(list_nil(list)) = node;
	list_next(node) = list_nil(list);
	list_size(list)++;

	return 0;
}

/***********************************************************************
 * Removes the 'node' from the 'list', and returns the 'node'. The
 * 'node' is not deallocated from memory, nor is the key element
 * associated with it deallocated. The memory deallocation must be
 * handled by the caller of this routine. It is safe to pass NULL in for
 * any of the parameters, as they are explicitly checked. The run-time
 * complexity is O(1).
 *
 * Parameters:
 *   list: The list to delete the 'node' from.
 *   node: The node to delete from the 'list'. This node must already be
 *       present in the list.
 *
 * Return value:
 *   Returns the node that gets deleted from the list or NULL on error.
 *   An error may be generated if NULL was passed in as one of the
 *   parameters.
 **********************************************************************/
list_node_t *list_delete(list_t *list, list_node_t *node)
{
	if (list == NULL || node == NULL || list_is_nil(node))
		return NULL;

	list_next(list_prev(node)) = list_next(node);
	list_prev(list_next(node)) = list_prev(node);
	list_size(list)--;

	return node;
}

/***********************************************************************
 * A variation of deletion that deletes the 'node' from the 'list' and
 * returns a pointer to the key of the deleted node. The 'node' is
 * deallocated from memory, while the nodes key is not deallocated from
 * memory. It is safe to pass NULL in for any of the parameters, as they
 * are explicitly checked. The run-time complexity is O(1).
 *
 * Parameters:
 *   list: The list to remove the 'node' from.
 *   node: The node to remove from the 'list'. This 'node' is dallocated
 *       from memory, while its key is not deallocated and it the
 *       reponsibility of the caller to deallocate.
 *
 * Return value:
 *   Returns the key of the node removed or NULL on error. An error may
 *   occur if NULL was passed in as one of the parameters.
 **********************************************************************/
void *list_remove(list_t *list, list_node_t *node)
{
	if (list == NULL || list_size(list) == 0 ||
	    node == NULL || list_is_nil(node))
		return NULL;

	list_node_t *rem = list_delete(list, node);
	void *key = list_key(rem);
	list_key(rem) = NULL;
	destroy_node(list, rem);

	/* ORIG:
	void *key = list_key(node);
	list_key(node) = NULL;
	destroy_node(list, node);
	END ORIG */

	return key;
}

/***********************************************************************
 * Creates a newly allocated list node from the 'key'.
 *
 * Parameters:
 *   key: The key to create the new node from.
 *
 * Return Value:
 *   Returns a newly allocated list node on success or NULL on error. An
 *   error may occur if the 'key' is NULL or if memory allocation fails.
 **********************************************************************/
static inline list_node_t *create_node(void *key)
{
	if (key == NULL)
		return NULL;

	list_node_t *node;
	if ((node = malloc(sizeof(list_node_t))) == NULL)
		return NULL;
	node->key = key;

	return node;
}

/***********************************************************************
 * Destorys the given 'node' from a list. The 'list' destroy function is
 * used to deallocated the node key from memory (if both key and destroy
 * function are present). The 'node' is also deallocated from memory.
 *
 * Parameters:
 *   list: The list to destroy the node from (uses the destroy function
 *       if present).
 *   node: The node to deallocate from memory (including deallocation of
 *       the key).
 * Return Value:
 *   None.
 **********************************************************************/
static inline void destroy_node(list_t *list, list_node_t *node)
{
	if (node == NULL)
		return;

	if (list->destroy != NULL && list_key(node) != NULL)
		list->destroy(list_key(node));
	free(node);
}

#endif
