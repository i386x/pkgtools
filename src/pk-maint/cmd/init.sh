#
#! \file    ./src/pk-maint/cmd/init.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-29 13:54:32 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Initialize project maintenance directory.
#

require_command touch
require_command cat

MAINTFILE='Maintfile'

GITIGNORE='.gitignore'
GITIGNORE_TEMPLATE='/upstream
/playground
'

[ -f $MAINTFILE ] || (
  if [ -z "$MAINTFILE_TEMPLATE" ]; then
    touch $MAINTFILE
  else
    echo $MAINTFILE_TEMPLATE > $MAINTFILE
  fi
)
[ -f $GITIGNORE ] || (
  echo $GITIGNORE_TEMPLATE > $GITIGNORE
)
