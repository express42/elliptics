/*
 * 2008+ Copyright (c) Evgeniy Polyakov <zbr@ioremap.net>
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#ifndef __CORE_H
#define __CORE_H

#define EL_HISTORY_SUFFIX	".history"

#define __unused		__attribute__ ((unused))

#define EL_ID_SIZE		20		/* Has to match selected hash type */
#define EL_MAX_NAME_LEN		64

#define EL_CONF_MAX_STR		512
#define EL_PRIV_SIZE		40960

#define EL_CONF_COMMENT		'#'
#define EL_CONF_DELIM		'='
#define EL_CONF_ADDR_DELIM	':'
#define EL_CONF_TIME_DELIM	'.'

#define DNET_TIMEOUT		5000

#endif /* __CORE_H */
