#!/usr/bin/env python3
"""Restore only the original six simulation preferences; retain the backup."""
import fcntl
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time

import mac_location_lab as original


def redacted(message):
    return re.sub(r'(?<![A-Za-z])[-+]?\d+\.\d+(?:[eE][-+]?\d+)?', '[number]', message.strip())[:1600]


def execute(args, stage):
    try:
        return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, timeout=20)
    except subprocess.TimeoutExpired:
        raise RuntimeError(stage + '超时；原始备份保留。')
    except OSError:
        raise RuntimeError(stage + '无法执行；原始备份保留。')


def missing_preference(stderr):
    lower = stderr.lower()
    if any(word in lower for word in ('permission denied', 'operation not permitted',
                                      'not authorized', 'access denied')):
        return False
    return ('domain/default pair' in lower and 'does not exist' in lower) or bool(
        re.search(r'\bdomain\s*\([^\n)]*\)\s+not found\b', lower))


def preference(domain, operation, key, value=None):
    uid = execute(['/usr/bin/id', '-u', '_locationd'], '查询定位服务用户')
    if uid.returncode or not uid.stdout.strip().isdigit():
        raise RuntimeError('无法确认定位服务用户；未修改参数。')
    helper = Path(__file__).resolve().with_name('LocationPreferences')
    if not helper.is_file():
        raise RuntimeError('完整精度定位组件缺失；停止操作。')
    args = ['/bin/launchctl', 'asuser', uid.stdout.strip(), '/usr/bin/sudo', '-n',
            '-H', '-u', '_locationd', str(helper), operation, domain, key]
    if value is not None:
        args += [str(value)]
    result = execute(args, '访问定位参数')
    if result.returncode:
        raise RuntimeError('定位参数访问失败（' + operation + ' ' + domain + '/' + key +
                           '，退出码 ' + str(result.returncode) + '）：\n' +
                           redacted(result.stderr))
    if operation == 'read':
        try:
            value = json.loads(result.stdout)['value']
        except (ValueError, KeyError, TypeError):
            raise RuntimeError('定位参数读取格式异常；未视为缺失。')
        if value is None:
            return None
        if type(value) not in (int, float) or not math.isfinite(value):
            raise RuntimeError('定位模拟参数类型或数值异常；未视为缺失。')
        return float(value)


def snapshot():
    return {domain: {key: preference(domain, 'read', key) for key in original.KEYS}
            for domain in original.DOMAINS}


def same(a, b):
    return a is b if a is None or b is None else math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-9)


def restore_checked(backup):
    before = snapshot()
    changed = 0
    for domain in original.DOMAINS:
        for key in original.KEYS:
            value = backup[domain][key]
            if same(value, before[domain][key]):
                continue
            preference(domain, 'delete' if value is None else 'write', key, value)
            changed += 1
    after = snapshot()
    if any(not same(backup[d][k], after[d][k]) for d in original.DOMAINS for k in original.KEYS):
        raise RuntimeError('参数读回核对不一致；原始备份保留。')
    return changed


def refresh_service():
    cache = execute(['/usr/bin/killall', '-u', 'root', 'cfprefsd'], '刷新偏好缓存')
    if cache.returncode and 'no matching processes' not in cache.stderr.lower():
        print('偏好缓存刷新提示：' + redacted(cache.stderr))
    old = execute(['/usr/bin/pgrep', '-x', 'locationd'], '查询定位服务').stdout.split()
    result = execute(['/bin/launchctl', 'kill', 'SIGTERM', 'system/com.apple.locationd'], '刷新定位服务')
    if result.returncode:
        print('定位服务刷新失败（退出码 ' + str(result.returncode) + '）：\n' + redacted(result.stderr))
        execute(['/usr/bin/notifyutil', '-p', 'com.apple.locationd/Prefs'], '通知定位服务')
        return False
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        current = execute(['/usr/bin/pgrep', '-x', 'locationd'], '查询定位服务').stdout.split()
        if current and not set(old).intersection(current):
            notice = execute(['/usr/bin/notifyutil', '-p', 'com.apple.locationd/Prefs'], '通知定位服务')
            return notice.returncode == 0
        time.sleep(.2)
    print('未确认定位服务重新启动，需要正常重启 Mac。')
    return False


def main():
    if sys.platform != 'darwin' or os.geteuid() != 0:
        raise RuntimeError('请通过「修复恢复.command」使用本机管理员授权运行。')
    state = original.STATE
    if not state.exists():
        print('没有工具备份目录；未修改参数。')
        return 0
    info = state.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
        raise RuntimeError('备份目录所有者或权限异常；停止恢复。')
    if not (state / 'original.json').exists():
        print('没有原始备份；未修改参数。')
        return 0
    fd = os.open(state / 'lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+') as lock:
        info = os.fstat(lock.fileno())
        if info.st_uid != 0 or not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600:
            raise RuntimeError('工具锁文件异常；停止恢复。')
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('另一个定位操作仍在运行，请等它退出后再恢复。')
        backup = original.read_backup()
        print('原始备份结构与权限有效。开始恢复六个定位模拟参数，不输出坐标。')
        changed = restore_checked(backup)
        print('恢复参数读回核对通过：6/6；本次修改 ' + str(changed) + ' 个参数。')
        try:
            restarted = refresh_service()
        except RuntimeError as error:
            print(str(error))
            restarted = False
        result = {'status': 'restored' if restarted else 'reboot_needed',
                  'preferences_match_original': True, 'locationd_restarted': restarted,
                  'original_backup_retained': True}
        print('RESULT_JSON ' + json.dumps(result, ensure_ascii=False))
        if restarted:
            print('定位服务已刷新。请刷新苹果地图的当前位置，确认实际落点。')
        else:
            print('六个参数已恢复并核对，但服务刷新未确认。请正常重启 Mac 后再检查地图。')
        print('原始备份仍保留。请暂时不要重新进行虚拟定位测试。')
        return 0 if restarted else 2


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, OSError) as error:
        print('恢复未确认：' + (str(error) if isinstance(error, RuntimeError) else
                              '备份读取或系统操作失败。') + '\n原始备份仍保留。', file=sys.stderr)
        print('RESULT_JSON ' + json.dumps({'status': 'failed', 'preferences_match_original': False,
                                           'original_backup_retained': True}))
        sys.exit(1)
