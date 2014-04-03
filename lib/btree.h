#ifndef BTREE_H
#define BTREE_H

struct btree_node_t {
	struct btree_node_t *parent;
	struct btree_node_t *left;
	struct btree_node_t *right;
	void *key;              /* The data this node holds */
};

struct btree_t {
	unsigned long size;
	int (*compare)(const void *key1, const void *key2);
	void (*destroy)(void *key);
	struct btree_node_t *root;
	struct btree_node_t *nil;  /* Sentinel representation (null node) */
};

struct btree_t *btree_create(int (*compare)(const void *key1, const void *key2),
		void (*destroy)(void *key));
void btree_destroy(struct btree_t *tree);
int btree_ins_left(struct btree_t *tree, struct btree_node_t *node,
		const void *key);
int btree_ins_right(struct btree_t *tree, struct btree_node_t *node,
		const void *key);
void btree_remove(struct btree_t *tree, struct btree_node_t *node);
struct btree_t *btree_merge(struct btree_t *left, struct btree_t *right,
		void *data);

#define btree_size(tree)    ((tree)->size)
#define btree_root(tree)    ((tree)->root)
#define btree_nil(tree)     ((tree)->nil)
#define btree_key(node)     ((node)->key)
#define btree_parent(node)  ((node)->parent)
#define btree_left(node)    ((node)->left)
#define btree_right(node)   ((node)->right)
#define btree_is_nil(node)  ((node)->key == NULL)
#define btree_is_leaf(node)  \
	((node)->left->key == NULL && (node)->right->key == NULL)
#define btree_rem_left(tree, node)  \
	(if (node) btree_remove(tree, btree_left(node));)
#define btree_rem_right(tree, node)  \
	(if (node) btree_remove(tree, btree_right(node));)

#endif
