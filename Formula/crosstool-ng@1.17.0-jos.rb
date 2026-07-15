# https://github.com/spastorino/homebrew/blob/ae335f108aac33938c5fd193856cc843c474626e/Library/Formula/crosstool-ng.rb#L4
# https://github.com/oe-lite-rpi/core/blob/3eeafeb848761e6cd941ea1cd1208b16d449d07d/recipes/crosstool-ng/crosstool-ng_1.17.0.oe.sig#L3
class CrosstoolNgAT1170Jos < Formula
  homepage 'http://crosstool-ng.org'
  url 'http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.17.0.tar.bz2'
  sha256 '12d9349eba248b72322c7f4ef369bd68078a5f85a369b7693226f62d5a6b4205'

  depends_on 'automake' => :build
  depends_on 'coreutils-jos' => :build
  depends_on 'wget'
  depends_on 'gnu-sed'
  depends_on 'gawk'
  depends_on 'binutils-jos'

  env :std

  patch :p1, :DATA

  def install
    system "./configure", "--prefix=#{prefix}",
           "--exec-prefix=#{prefix}",
           "--with-objcopy=gobjcopy",
           "--with-objdump=gobjdump",
           "--with-readelf=greadelf",
           "--with-libtool=glibtool",
           "--with-libtoolize=glibtoolize",
           "--with-install=ginstall",
           "--with-sed=gsed",
           "--with-awk=gawk"
    # Must be done in two steps
    system "make"
    system "make install"
  end

  def test
    system "#{bin}/ct-ng version"
  end

  def caveats; <<~EOS
    If building a cross compiler your may expirience the following error:
      error: elf.h: No such file or directory

    To fix it, perform the following:
      curl https://raw.github.com/gist/3769372/98e0a084470d2d6be7b4b61551ef00d44c682b4a/elf.h > elf.h
      cp -p elf.h /usr/local/include/
    EOS
  end
end

__END__
diff --git a/kconfig/zconf.gperf b/kconfig/zconf.gperf
index c9e690e..21e79e4 100644
--- a/kconfig/zconf.gperf
+++ b/kconfig/zconf.gperf
@@ -7,6 +7,15 @@
 %pic
 %struct-type

+%{
+# ifndef offsetof
+#  include <stddef.h>
+#  ifndef offsetof
+#   define offsetof(st, m) ((size_t)(&((st *)0)->m))
+#  endif
+# endif
+%}
+
 struct kconf_id;

 static struct kconf_id *kconf_id_lookup(register const char *str, register unsigned int len);
diff --git a/kconfig/Makefile.org b/kconfig/Makefile
index 3474e5c..74f6b68 100644
--- a/kconfig/Makefile.org
+++ b/kconfig/Makefile
@@ -35,20 +35,24 @@ conf_SRC = conf.c
 conf_OBJ = $(patsubst %.c,%.o,$(conf_SRC))
 conf_DEP = $(patsubst %.o,%.dep,$(conf_OBJ))
 $(conf_OBJ) $(conf_DEP): CFLAGS += $(INTL_CFLAGS)
+conf: LDFLAGS += -lintl

 # What's needed to build 'mconf'
 mconf_SRC = mconf.c
 mconf_OBJ = $(patsubst %.c,%.o,$(mconf_SRC))
 mconf_DEP = $(patsubst %.c,%.dep,$(mconf_SRC))
 $(mconf_OBJ) $(mconf_DEP): CFLAGS += $(NCURSES_CFLAGS) $(INTL_CFLAGS)
-mconf: LDFLAGS += $(NCURSES_LDFLAGS)
+# mconf: LDFLAGS += $(NCURSES_LDFLAGS)
+mconf: LDFLAGS += -lintl $(NCURSES_LDFLAGS)

 # What's needed to build 'nconf'
 nconf_SRC = nconf.c nconf.gui.c
 nconf_OBJ = $(patsubst %.c,%.o,$(nconf_SRC))
 nconf_DEP = $(patsubst %.c,%.dep,$(nconf_SRC))
-$(nconf_OBJ) $(nconf_DEP): CFLAGS += $(INTL_CFLAGS) -I/usr/include/ncurses
-nconf: LDFLAGS += -lmenu -lpanel -lncurses
+# $(nconf_OBJ) $(nconf_DEP): CFLAGS += $(INTL_CFLAGS) -I/usr/include/ncurses
+# nconf: LDFLAGS += -lmenu -lpanel -lncurses
+$(nconf_OBJ) $(nconf_DEP): CFLAGS += -I/usr/include/ncurses/ $(INTL_CFLAGS)
+nconf: LDFLAGS += -lintl -lmenu -lpanel -lncurses

 # Under Cygwin, we need to auto-import some libs (which ones, exactly?)
 # for mconf and nconf to lin properly.
diff --git a/scripts/crosstool-NG.sh.in b/scripts/crosstool-NG.sh.in
--- a/scripts/crosstool-NG.sh.in
+++ b/scripts/crosstool-NG.sh.in
@@ -66,6 +66,9 @@
             *" "*)
                 CT_Abort "'CT_${d}_DIR'='${dir}' contains a space in it.\nDon't use spaces in paths, it breaks things."
                 ;;
+            *:*)
+                CT_Abort "'CT_${d}_DIR'='${dir}' contains a colon in it.\nDon't use colons in paths, it breaks things."
+                ;;
         esac
 done
diff --git a/scripts/functions b/scripts/functions
--- a/scripts/functions
+++ b/scripts/functions
@@ -71,16 +71,15 @@
                                 printf "\nRe-trying last command.\n\n"
                                 break
                             fi
-                            ;;&
+                            ;;
                         3)  break;;
-                        *)  printf "\nPlease exit with one of these values:\n"
-                            printf "    1  fixed, continue with next build command\n"
-                            if [ -n "${cur_cmd}" ]; then
-                                printf "    2  repeat this build command\n"
-                            fi
-                            printf "    3  abort build\n"
-                            ;;
                     esac
+                    printf "\nPlease exit with one of these values:\n"
+                    printf "    1  fixed, continue with next build command\n"
+                    if [ -n "${cur_cmd}" ]; then
+                        printf "    2  repeat this build command\n"
+                    fi
+                    printf "    3  abort build\n"
                 done
                 exit $result
             )
@@ -88,7 +87,7 @@
             # Restore the trap handler
             eval "${old_trap}"
             case "${result}" in
-                1)  rm -f "${CT_WORK_DIR}/backtrace"; return;;
+                1)  rm -f "${CT_WORK_DIR}/backtrace"; touch "${CT_BUILD_DIR}/skip"; return;;
                 2)  rm -f "${CT_WORK_DIR}/backtrace"; touch "${CT_BUILD_DIR}/repeat"; return;;
                 # 3 is an abort, continue...
             esac
@@ -258,7 +257,12 @@
         "${@}" 2>&1 |CT_DoLog "${level}"
         ret="${?}"
         if [ -f "${CT_BUILD_DIR}/repeat" ]; then
+            rm -f "${CT_BUILD_DIR}/repeat"
             continue
+        elif [ -f "${CT_BUILD_DIR}/skip" ]; then
+            rm -f "${CT_BUILD_DIR}/skip"
+            ret=0
+            break
         else
             break
         fi