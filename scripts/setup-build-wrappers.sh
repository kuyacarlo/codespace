#!/bin/bash
set -e

echo "🔧 Setting up build-time wrappers for rootless Podman..."

# Wrapper for chown
dpkg-divert --local --divert /usr/bin/chown.real --rename /usr/bin/chown
printf '#!/bin/sh\n/usr/bin/chown.real "$@" || true\n' > /usr/bin/chown
chmod +x /usr/bin/chown

# Wrapper for chgrp
dpkg-divert --local --divert /usr/bin/chgrp.real --rename /usr/bin/chgrp
printf '#!/bin/sh\n/usr/bin/chgrp.real "$@" || true\n' > /usr/bin/chgrp
chmod +x /usr/bin/chgrp

# Wrapper for dpkg-statoverride
dpkg-divert --local --divert /usr/bin/dpkg-statoverride.real --rename /usr/bin/dpkg-statoverride
printf '#!/bin/sh\n/usr/bin/dpkg-statoverride.real "$@" || true\n' > /usr/bin/dpkg-statoverride
chmod +x /usr/bin/dpkg-statoverride

# Wrapper for su
dpkg-divert --local --divert /usr/bin/su.real --rename /usr/bin/su
printf '#!/bin/bash\ncmd=""\nis_c=0\nfor arg in "$@"; do\n  if [ "$is_c" = "1" ]; then\n    cmd="$arg"\n    break\n  fi\n  if [ "$arg" = "-c" ] || [ "$arg" = "--command" ]; then\n    is_c=1\n  fi\ndone\nif [ -n "$cmd" ]; then\n  exec /bin/bash -c "$cmd"\nelse\n  exec /usr/bin/su.real "$@"\nfi\n' > /usr/bin/su
chmod +x /usr/bin/su

# Wrapper for install
dpkg-divert --local --divert /usr/bin/install.real --rename /usr/bin/install
printf '#!/bin/bash\nargs=()\nskip=0\nfor arg in "$@"; do\n  if [ "$skip" = "1" ]; then\n    skip=0\n    continue\n  fi\n  if [ "$arg" = "-o" ] || [ "$arg" = "-g" ] || [ "$arg" = "--owner" ] || [ "$arg" = "--group" ]; then\n    skip=1\n    continue\n  fi\n  args+=("$arg")\ndone\nexec /usr/bin/install.real "${args[@]}"\n' > /usr/bin/install
chmod +x /usr/bin/install

echo "✅ Build-time wrappers successfully configured."
