// SPDX-License-Identifier: GPL-2.0

/* Lean nlattr replacement export metadata. */

#include <linux/export.h>
#include <linux/gfp.h>
#include <linux/skbuff.h>
#include <linux/types.h>
#include <net/netlink.h>

int __nla_validate(const struct nlattr *head, int len, int maxtype,
		   const struct nla_policy *policy, unsigned int validate,
		   struct netlink_ext_ack *extack);
int __nla_parse(struct nlattr **tb, int maxtype, const struct nlattr *head,
		int len, const struct nla_policy *policy, unsigned int validate,
		struct netlink_ext_ack *extack);
void nla_get_range_unsigned(const struct nla_policy *pt,
			    struct netlink_range_validation *range);
void nla_get_range_signed(const struct nla_policy *pt,
			  struct netlink_range_validation_signed *range);

int nla_policy_len(const struct nla_policy *p, int n);
struct nlattr *nla_find(const struct nlattr *head, int len, int attrtype);
ssize_t nla_strscpy(char *dst, const struct nlattr *nla, size_t dstsize);
char *nla_strdup(const struct nlattr *nla, gfp_t flags);
int nla_memcpy(void *dest, const struct nlattr *src, int count);
int nla_memcmp(const struct nlattr *nla, const void *data, size_t size);
int nla_strcmp(const struct nlattr *nla, const char *str);

EXPORT_SYMBOL(__nla_validate);
EXPORT_SYMBOL(__nla_parse);
EXPORT_SYMBOL(nla_policy_len);
EXPORT_SYMBOL(nla_find);
EXPORT_SYMBOL(nla_strscpy);
EXPORT_SYMBOL(nla_strdup);
EXPORT_SYMBOL(nla_memcpy);
EXPORT_SYMBOL(nla_memcmp);
EXPORT_SYMBOL(nla_strcmp);

#ifdef CONFIG_NET
struct nlattr *__nla_reserve(struct sk_buff *skb, int attrtype, int attrlen);
struct nlattr *__nla_reserve_64bit(struct sk_buff *skb, int attrtype,
				   int attrlen, int padattr);
void *__nla_reserve_nohdr(struct sk_buff *skb, int attrlen);
struct nlattr *nla_reserve(struct sk_buff *skb, int attrtype, int attrlen);
struct nlattr *nla_reserve_64bit(struct sk_buff *skb, int attrtype,
				 int attrlen, int padattr);
void *nla_reserve_nohdr(struct sk_buff *skb, int attrlen);
void __nla_put(struct sk_buff *skb, int attrtype, int attrlen,
	       const void *data);
void __nla_put_64bit(struct sk_buff *skb, int attrtype, int attrlen,
		     const void *data, int padattr);
void __nla_put_nohdr(struct sk_buff *skb, int attrlen, const void *data);
int nla_put(struct sk_buff *skb, int attrtype, int attrlen, const void *data);
int nla_put_64bit(struct sk_buff *skb, int attrtype, int attrlen,
		  const void *data, int padattr);
int nla_put_nohdr(struct sk_buff *skb, int attrlen, const void *data);
int nla_append(struct sk_buff *skb, int attrlen, const void *data);

EXPORT_SYMBOL(__nla_reserve);
EXPORT_SYMBOL(__nla_reserve_64bit);
EXPORT_SYMBOL(__nla_reserve_nohdr);
EXPORT_SYMBOL(nla_reserve);
EXPORT_SYMBOL(nla_reserve_64bit);
EXPORT_SYMBOL(nla_reserve_nohdr);
EXPORT_SYMBOL(__nla_put);
EXPORT_SYMBOL(__nla_put_64bit);
EXPORT_SYMBOL(__nla_put_nohdr);
EXPORT_SYMBOL(nla_put);
EXPORT_SYMBOL(nla_put_64bit);
EXPORT_SYMBOL(nla_put_nohdr);
EXPORT_SYMBOL(nla_append);
#endif
