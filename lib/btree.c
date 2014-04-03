#ifndef BTREE_C
#define BTREE_C

#include <stdlib.h>
#include "btree.h"

#define BTREE_LEFT  1
#define BTREE_RIGHT 2

/***********************************************************************
 * Allocates, initializes, and returns a binary tree container. This
 * function should be used to create a binary tree.
 *
 * Parameters:
 *   compare: The comparison function used to insert elements into the
 *     binary tree. The comparison function should return -1 when 'key1'
 *     is less than 'key2', +1 when 'key1' is greater than 'key2', or 0
 *     when 'key1' and 'key2' are equal.
 *   destroy: A function used to deallocate tree nodes from memory. This
 *     function may be the standard kfree(3) function, or a user-defined
 *     function in the case of a complex tree node.
 *
 * Return Value:
 *   Returns a pointer to an rbtree_t that represents a tree strucutre,
 *   or NULL on error (most likely an error in memory allocation).
 **********************************************************************/
struct btree_t *btree_create(int (*compare)(const void *key1, const void *key2),
		void (*destroy)(void *key))
{
	struct btree_t *tree;
	if ((tree = malloc(sizeof(struct btree_t))) == NULL)
		return NULL;

	if ((tree->nil = malloc(sizeof(struct btree_t))) == NULL) {
		free(tree);
		return NULL;
	}
	tree->nil->parent = NULL;
	tree->nil->left = NULL;
	tree->nil->right = NULL;

	tree->size = 0;
	tree->compare = compare;
	tree->destroy = destroy;
	tree->root = btree_nil(tree);

	return tree;
}

/***********************************************************************
 * Iteratively destroys all elements of the tree. The tree strcuture is
 * also deallocated from memory. Once this function is called on a tree,
 * no other tree operations are valid for the given 'tree', and it has
 * no allocated memory associated with it.
 *  
 * Parameters:
 *   tree: The binary tree to destroy.
 *  
 * Return Value:
 *   None.
 **********************************************************************/
void btree_destroy(struct btree_t *tree)
{
	btree_remove(tree, btree_root(tree));
	free(tree->nil);
	free(tree);
}

/***********************************************************************
 * A static (private) function to insert a data 'key' into the right or
 * left subtree of the given 'node', which is part of the binary 'tree'.
 *
 * Parameters:
 *   tree: The binary tree to insert a new node into.
 *   node: The node to place the new node into.
 *   key: The data element to create a new node from.
 *   type: Either BTREE_LEFT or BTREE_RIGHT that specifies if the newly
 *     created node should be rooted as the left or right subtree in the
 *     given 'node'.
 *
 * Return Value:
 *   Returns 0 on success, or -1 on error.
 ***********************************************************************/
static int btree_insert(struct btree_t *tree, struct btree_node_t *node,
		const void *key, int type)
{
	struct btree_node_t *new_node;

	if ((new_node = malloc(sizeof(struct btree_node_t))) == NULL)
		return -1;

	new_node->parent = node;
	new_node->left = btree_nil(tree);
	new_node->right = btree_nil(tree);
	new_node->key = (void *)key;

	if (node == NULL) {
		if (btree_size(tree) > 0)
			return -1;
		tree->root = new_node;
	} else {
		/* Based on the type of insert (right or left), get position of
		 * insertion. */
		if (type == BTREE_LEFT) {
			if (!btree_is_nil(btree_left(node)))
				return -1;
			node->left = new_node;
		} else {  /* Insert right */
			if (!btree_is_nil(btree_right(node)))
				return -1;
			node->right = new_node;
		}
	}
	tree->size++;

	return 0;
}

/***********************************************************************
 * Inserts the given 'key' into a new binary node, and added to the
 * left subtree of the given 'node' element.
 *
 * Parameters:
 *   tree: The binary tree to insert the given node as the left
 *     sub-tree.
 *   node: The node to used to place the new element in the left
 *     sub-tree.
 *   key: The data used to create the new node to insert.
 *
 * Return Value:
 *   Returns -1 on error or 0 on success.
 ***********************************************************************/
int btree_ins_left(struct btree_t *tree, struct btree_node_t *node,
		const void *key)
{
	return btree_insert(tree, node, key, BTREE_LEFT);
}

/***********************************************************************
 * Inserts the given 'key' into a new binary node, and added to the
 * right subtree of the given 'node' element.
 *
 * Parameters:
 *   tree: The binary tree to insert the given node as the right
 *     sub-tree.
 *   node: The node to used to place the new element in the right
 *     sub-tree.
 *   key: The data used to create the new node to insert.
 *
 * Return Value:
 *   Returns -1 on error or 0 on success.
 ***********************************************************************/
int btree_ins_right(struct btree_t *tree, struct btree_node_t *node,
		const void *key)
{
	return btree_insert(tree, node, key, BTREE_RIGHT);
}

/***********************************************************************
 * Recursively removes the given 'node' from the 'tree'.
 *
 * Parameters:
 *   tree: The binary tree to destroy.
 *   node: The node to recursively remove all of its elements.
 *
 * Return Value:
 *   None.
 ***********************************************************************/
void btree_remove(struct btree_t *tree, struct btree_node_t *node)
{
	/* Base case. Don't actually remove the sentinel. */
	if (btree_is_nil(node)) {
		return;
	} else {  /* Recursive case. Remove the node structure. */
		btree_remove(tree, btree_left(node));
		btree_remove(tree, btree_right(node));
		if (tree->destroy)
			tree->destroy(btree_key(node));
		free(node);
		node = NULL;
		tree->size--;
	}
}

/***********************************************************************
 * Merge the 'left' and 'right' trees into a newly formed binary tree
 * as its left and right children (respectively). The 'data' provided is
 * created as the root node of the new tree.
 *
 * A newly formed binary tree is returned as the node created with the
 * given 'data' as the root, and the 'left' and 'right' trees as the
 * roots left and right subtree (respectively).
 *
 * Parameters:
 *   left: The left binary tree to root at the left subtree of the newly
 *     created root tree.
 *   right: The right binary tree to root at the right subtree of the
 *     newly created root tree.
 *   data: The data used to construct a new node that is placed as the
 *     root of the newly created merged tree.
 *
 * Return Value:
 *   Returns the newly created (allocated) merged tree on success, or
 *   NULL on failre.
 ***********************************************************************/
struct btree_t *btree_merge(struct btree_t *left, struct btree_t *right,
		void *data)
{
	struct btree_t *merge;
	if ((merge = btree_create(left->compare, left->destroy)) == NULL)
		return NULL;

	if (btree_ins_left(merge, NULL, data) != 0) {
		btree_destroy(merge);
		return NULL;
	}

	btree_root(merge)->left = btree_root(left);
	btree_root(merge)->right = btree_root(right);

	merge->size = merge->size + btree_size(left) + btree_size(right);

	left->root = NULL;
	left->size = 0;
	right->root = NULL;
	right->size = 0;

	return 0;
}

#endif
