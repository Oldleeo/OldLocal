#!/usr/bin/env python3
import os
import sys

# Isolated Python disables user site packages and environment injection.
# Only modules packaged with this application are imported.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stderr = sys.stdout
if os.geteuid() == 0:
    os.setgroups([])
    os.setgid(0)
    os.setuid(0)
import no_reboot_location

try:
    sys.exit(no_reboot_location.main())
except (RuntimeError, ValueError, TypeError, OSError) as error:
    print(str(error) if isinstance(error, RuntimeError) else
          '输入、备份或系统操作异常；未假定成功。', flush=True)
    no_reboot_location.emit('failed', original_backup_retained=True)
    sys.exit(1)
