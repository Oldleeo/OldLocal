#!/usr/bin/env python3
"""Same-Mac experiment using a normal, UID-scoped SIGTERM service refresh."""
import argparse
import fcntl
import json
import os
import stat
import sys
import time

import mac_location_lab as original
import repair_location as recovery


def emit(status, **fields):
    print('RESULT_JSON ' + json.dumps(dict(status=status, **fields), ensure_ascii=False), flush=True)


def location_pids():
    result = recovery.execute(['/usr/bin/pgrep', '-u', '_locationd', '-x', 'locationd'], '查询定位服务')
    if result.returncode not in (0, 1):
        raise RuntimeError('无法查询定位服务：' + recovery.redacted(result.stderr))
    return set(result.stdout.split())


def restart_normal(clear_cache=True):
    old = location_pids()
    if not old:
        raise RuntimeError('定位服务未运行；停止测试。')
    if clear_cache:
        result = recovery.execute(['/usr/bin/killall', '-TERM', '-u', 'root', 'cfprefsd'], '刷新偏好缓存')
        if result.returncode and 'no matching processes' not in result.stderr.lower():
            raise RuntimeError('无法刷新偏好缓存：' + recovery.redacted(result.stderr))
        time.sleep(.5)
    # Normal process signal, limited by both service name and real user ID.
    result = recovery.execute(['/usr/bin/killall', '-TERM', '-u', '_locationd', 'locationd'], '正常刷新定位服务')
    if result.returncode:
        raise RuntimeError('系统拒绝正常刷新定位服务：' + recovery.redacted(result.stderr))
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        current = location_pids()
        if current and not old.intersection(current):
            notice = recovery.execute(['/usr/bin/notifyutil', '-p', 'com.apple.locationd/Prefs'], '通知定位服务')
            if notice.returncode:
                raise RuntimeError('定位服务已重新运行，但参数刷新通知失败。')
            print('已确认定位服务以新进程重新运行；Mac 无需重启。', flush=True)
            return
        time.sleep(.2)
    raise RuntimeError('未确认定位服务在十五秒内重新运行；未继续写入坐标。')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=('set', 'reset'))
    parser.add_argument('--latitude', type=float)
    parser.add_argument('--longitude', type=float)
    args = parser.parse_args()
    if sys.platform != 'darwin' or os.geteuid() != 0:
        raise RuntimeError('需要本机管理员授权。')
    values = original.validate_location(args.latitude, args.longitude, 10) if args.command == 'set' else None
    original.private_directory()
    fd = os.open(original.STATE / 'lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+') as lock:
        info = os.fstat(lock.fileno())
        if info.st_uid != 0 or not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600:
            raise RuntimeError('工具锁文件异常。')
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('另一个定位操作仍在运行。')
        backup_path = original.STATE / 'original.json'
        if args.command == 'reset':
            if not backup_path.exists():
                print('没有原始备份；未修改参数。')
                return 0
            backup = original.read_backup()
            recovery.restore_checked(backup)
            try:
                restart_normal()
            except RuntimeError as error:
                print(str(error), flush=True)
                emit('preferences_restored_service_refresh_unconfirmed', preferences_match_original=True,
                     original_backup_retained=True)
                return 2
            recovery.restore_checked(backup)
            emit('restored', preferences_match_original=True, locationd_restarted=True,
                 original_backup_retained=True)
            print('恢复参数读回核对通过：6/6。请刷新地图确认实际落点。', flush=True)
            return 0
        # Validate read access and the saved backup before attempting any refresh.
        before = recovery.snapshot()
        if backup_path.exists():
            original.read_backup()
        else:
            original.save_backup(before)
        print('先验证正常刷新方式；通过前不修改坐标。', flush=True)
        try:
            restart_normal(clear_cache=False)
        except RuntimeError as error:
            print(str(error), flush=True)
            emit('refresh_blocked', coordinates_written=False, original_backup_retained=True)
            return 1
        try:
            for domain in original.DOMAINS:
                for key, value in zip(original.KEYS, values):
                    recovery.preference(domain, 'write', key, value)
            restart_normal()
            actual = recovery.snapshot()
            if any(not recovery.same(actual[d][k], v) for d in original.DOMAINS
                   for k, v in zip(original.KEYS, values)):
                raise RuntimeError('目标模拟参数读回核对失败。')
        except RuntimeError as error:
            print('设置未确认：' + str(error), flush=True)
            try:
                recovery.restore_checked(before)
                try:
                    restart_normal()
                    refreshed = True
                except RuntimeError as restore_error:
                    print(str(restore_error), flush=True)
                    refreshed = False
                emit('set_failed_parameters_rolled_back', preferences_match_before=True,
                     locationd_restarted=refreshed, original_backup_retained=True)
            except RuntimeError as restore_error:
                print('恢复未确认：' + str(restore_error), flush=True)
                emit('recovery_needed', original_backup_retained=True)
            return 1
        emit('applied', simulation_preferences_verified=True, locationd_restarted=True,
             map_location_verified=False, original_backup_retained=True)
        print('六个目标参数已核对，定位服务已刷新。现在需要在地图验证实际位置。', flush=True)
        return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, TypeError, OSError) as error:
        print(str(error) if isinstance(error, RuntimeError) else '输入、备份或系统操作异常；未假定成功。',
              file=sys.stderr, flush=True)
        emit('failed', original_backup_retained=True)
        sys.exit(1)
