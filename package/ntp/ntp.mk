################################################################################
#
# ntp
#
################################################################################

NTP_VERSION_MAJOR = 4.2
NTP_VERSION_MINOR = 8
NTP_VERSION_POINT = 18
NTP_VERSION = $(NTP_VERSION_MAJOR).$(NTP_VERSION_MINOR)p$(NTP_VERSION_POINT)
NTP_SITE = https://www.eecis.udel.edu/~ntp/ntp_spool/ntp4/ntp-$(NTP_VERSION_MAJOR)
NTP_DEPENDENCIES = host-pkgconf libevent
NTP_LICENSE = NTP
NTP_LICENSE_FILES = COPYRIGHT
NTP_CPE_ID_VENDOR = ntp
NTP_CPE_ID_VERSION = $(NTP_VERSION_MAJOR).$(NTP_VERSION_MINOR)
NTP_CPE_ID_UPDATE = p$(NTP_VERSION_POINT)
NTP_SELINUX_MODULES = ntp
NTP_CONF_ENV = ac_cv_lib_md5_MD5Init=no POSIX_SHELL=/bin/sh
NTP_CONF_OPTS = \
	--with-shared \
	--program-transform-name=s,,, \
	--disable-tickadj \
	--disable-debugging \
	--with-yielding-select=yes \
	--disable-local-libevent

# 0002-ntp-syscalls-fallback.patch
NTP_AUTORECONF = YES

ifeq ($(BR2_PACKAGE_OPENSSL),y)
NTP_CONF_OPTS += --with-crypto --enable-openssl-random --enable-verbose-ssl
NTP_DEPENDENCIES += openssl
else
NTP_CONF_OPTS += --without-crypto --disable-openssl-random
endif

ifeq ($(BR2_TOOLCHAIN_HAS_SSP),y)
NTP_CONF_OPTS += --with-hardenfile=linux
else
NTP_CONF_OPTS += --with-hardenfile=default
endif

ifeq ($(BR2_PACKAGE_LIBCAP),y)
NTP_CONF_OPTS += --enable-linuxcaps
NTP_DEPENDENCIES += libcap
define NTP_USERS
	ntp -1 ntp -1 * - - - ntpd user
endef
NTP_DAEMON_EXTRA_ARGS = -u ntp:ntp
else
NTP_CONF_OPTS += --disable-linuxcaps
endif

ifeq ($(BR2_PACKAGE_LIBEDIT),y)
NTP_CONF_OPTS += --with-lineeditlibs=edit
NTP_DEPENDENCIES += libedit
else
NTP_CONF_OPTS += --without-lineeditlibs
endif

ifeq ($(BR2_PACKAGE_NTP_NTPSNMPD),y)
NTP_CONF_OPTS += \
	--with-net-snmp-config=$(STAGING_DIR)/usr/bin/net-snmp-config
NTP_DEPENDENCIES += netsnmp
else
NTP_CONF_OPTS += --without-ntpsnmpd
endif

ifeq ($(BR2_PACKAGE_NTP_NTPD_ATOM_PPS),y)
NTP_CONF_OPTS += --enable-ATOM
NTP_DEPENDENCIES += pps-tools
else
NTP_CONF_OPTS += --disable-ATOM
endif

ifeq ($(BR2_PACKAGE_NTP_NTP_SHM_CLK),y)
NTP_CONF_OPTS += --enable-SHM
else
NTP_CONF_OPTS += --disable-SHM
endif

ifeq ($(BR2_PACKAGE_NTP_SNTP),y)
NTP_CONF_OPTS += --with-sntp
else
NTP_CONF_OPTS += --without-sntp
endif

NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTP_KEYGEN) += util/ntp-keygen
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTP_WAIT) += scripts/ntp-wait/ntp-wait
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTPDATE) += ntpdate/ntpdate
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTPDC) += ntpdc/ntpdc
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTPQ) += ntpq/ntpq
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTPSNMPD) += ntpsnmpd/ntpsnmpd
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTPTIME) += util/ntptime
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_NTPTRACE) += scripts/ntptrace/ntptrace
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_SNTP) += sntp/sntp
NTP_INSTALL_FILES_$(BR2_PACKAGE_NTP_TICKADJ) += util/tickadj

define NTP_INSTALL_TARGET_CMDS
	$(if $(BR2_PACKAGE_NTP_NTPD), install -m 755 $(@D)/ntpd/ntpd $(TARGET_DIR)/usr/sbin/ntpd)
	test -z "$(NTP_INSTALL_FILES_y)" || install -m 755 $(addprefix $(@D)/,$(NTP_INSTALL_FILES_y)) $(TARGET_DIR)/usr/bin/
	$(INSTALL) -m 644 package/ntp/ntpd.etc.conf $(TARGET_DIR)/etc/ntp.conf
endef

# This script will step the time if there is a large difference
# before ntpd takes over the necessary slew adjustments
ifeq ($(BR2_PACKAGE_NTP_SNTP),y)
define NTP_INSTALL_INIT_SYSV_SNTP
	$(INSTALL) -D -m 755 package/ntp/S48sntp $(TARGET_DIR)/etc/init.d/S48sntp
endef
endif

ifeq ($(BR2_PACKAGE_NTP_NTPD),y)
define NTP_INSTALL_INIT_SYSV_NTPD
	mkdir -p $(TARGET_DIR)/etc/init.d
	sed -e 's%@NTPD_EXTRA_ARGS@%$(NTP_DAEMON_EXTRA_ARGS)%g' \
		package/ntp/S49ntp.in \
		> $(TARGET_DIR)/etc/init.d/S49ntp
	chmod 0755 $(TARGET_DIR)/etc/init.d/S49ntp
endef

define NTP_INSTALL_INIT_SYSTEMD
	mkdir -p $(TARGET_DIR)/usr/lib/systemd/system
	sed -e 's%@NTPD_EXTRA_ARGS@%$(NTP_DAEMON_EXTRA_ARGS)%g' \
		package/ntp/ntpd.service.in \
		> $(TARGET_DIR)/usr/lib/systemd/system/ntpd.service
endef
endif

define NTP_INSTALL_INIT_SYSV
	$(NTP_INSTALL_INIT_SYSV_NTPD)
	$(NTP_INSTALL_INIT_SYSV_SNTP)
endef

$(eval $(autotools-package))
