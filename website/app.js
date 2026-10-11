(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const menu = $('.menu-button');
  const nav = $('#main-nav');
  if (menu && nav) {
    const close = () => { menu.setAttribute('aria-expanded', 'false'); menu.setAttribute('aria-label', '展开导航'); nav.classList.remove('open'); };
    menu.addEventListener('click', () => {
      const open = menu.getAttribute('aria-expanded') !== 'true';
      menu.setAttribute('aria-expanded', String(open)); menu.setAttribute('aria-label', open ? '收起导航' : '展开导航');
      nav.classList.toggle('open', open);
    });
    nav.querySelectorAll('a').forEach(link => link.addEventListener('click', close));
    document.addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
    document.addEventListener('click', event => { if (!menu.contains(event.target) && !nav.contains(event.target)) close(); });
  }

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if ('IntersectionObserver' in window && !reduceMotion) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add('is-visible'); observer.unobserve(entry.target); } });
    }, { threshold: 0.08 });
    document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
    document.documentElement.classList.add('js-ready');
  }

  const places = {
    paris: { name: '巴黎 · 埃菲尔铁塔', lat: 48.8584, lon: 2.2945 },
    tokyo: { name: '东京 · 东京塔', lat: 35.6586, lon: 139.7454 },
    seoul: { name: '首尔 · 市中心', lat: 37.566983, lon: 126.978235 }
  };
  let current = places.paris;
  let copyTimer;
  const coordinateText = value => `${value.lat.toFixed(6)}, ${value.lon.toFixed(6)}`;
  function showPlace(value, key = null) {
    current = value;
    $('#demo-place').textContent = value.name;
    $('#demo-coordinate').textContent = coordinateText(value);
    $('#coordinate-input').value = coordinateText(value);
    $('#demo-pin').setAttribute('transform', `translate(${(value.lon + 180) / 360 * 1000} ${(90 - value.lat) / 180 * 520})`);
    $('#coordinate-error').textContent = '';
    $('#coordinate-input').removeAttribute('aria-invalid');
    document.querySelectorAll('[data-place]').forEach(button => {
      const active = button.dataset.place === key;
      button.classList.toggle('active', active); button.setAttribute('aria-pressed', String(active));
    });
    clearTimeout(copyTimer);
    $('#copy-coordinate span').textContent = '复制坐标';
  }
  if ($('#coordinate-form')) {
    document.querySelectorAll('[data-place]').forEach(button => button.addEventListener('click', () => showPlace(places[button.dataset.place], button.dataset.place)));
    $('#coordinate-form').addEventListener('submit', event => {
      event.preventDefault();
      const tokens = $('#coordinate-input').value.replace(/，/g, ',').replace(/−/g, '-').trim().split(',').map(s => s.trim());
      const numeric = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;
      if (tokens.length !== 2 || !tokens.every(t => numeric.test(t))) {
        $('#coordinate-error').textContent = '请输入「纬度, 经度」，例如 48.858400, 2.294500。';
        $('#coordinate-input').setAttribute('aria-invalid', 'true'); return;
      }
      const [lat, lon] = tokens.map(Number);
      if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        $('#coordinate-error').textContent = '纬度需在 −90～90，经度需在 −180～180。';
        $('#coordinate-input').setAttribute('aria-invalid', 'true'); return;
      }
      showPlace({name: '你的预览落点', lat, lon});
    });
    $('#copy-coordinate').addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(coordinateText(current));
        $('#copy-coordinate span').textContent = '已复制';
      } catch {
        $('#coordinate-input').focus(); $('#coordinate-input').select();
        $('#copy-coordinate span').textContent = '坐标已选中，请复制';
      }
      copyTimer = setTimeout(() => { $('#copy-coordinate span').textContent = '复制坐标'; }, 2400);
    });
  }

  // Enable editable controls only after the local submit guard is installed.
  if ($('#coordinate-form')) {
    $('#coordinate-input').disabled = false;
    $('#coordinate-form button[type="submit"]').disabled = false;
  }

  const features = {
    favorites: { image: 'favorites.webp', alt: '收藏卡片上的备注、分组、应用和删除按钮', kicker: 'SAVE IT. NAME IT. USE IT.', title: ['一个名字，', '记住一个落点。'], description: '给常用坐标添加备注，点击收藏卡片上的「应用」，直接切换到这个位置。', points: ['点击卡片填回坐标，点击「应用」才会切换', '删除入口清晰，误删可以从「最近删除」恢复', '收藏保存在本机，更新应用后继续使用'], anchor: 'favorites' },
    groups: { image: 'groups.webp', alt: '分组管理窗口中的重命名、删除和撤销按钮', kicker: 'A LITTLE ORDER. A LOT LESS SEARCHING.', title: ['分门别类，', '更快找到下一站。'], description: '工作、旅行、测试。让不同用途的位置各有归处，筛选一下就能找到。', points: ['分组旁「管理」可重命名或删除', '删除分组后，位置移到「未分组」并保留数据', '管理窗口内可以撤销最近一次分组操作'], anchor: 'favorites' },
    ip: { image: 'ip.webp', alt: '公开 IP 8.8.8.8 的区域查询结果', kicker: 'SEE WHERE YOUR NETWORK POINTS.', title: ['网络的出口，', '也有一个落点。'], description: '输入 IPv4 / IPv6，或手动查询当前网络出口，查看它对应的区域与估计坐标。', points: ['查询由 ipapi.co 提供，需要网络', 'VPN 或代理可能使结果对应出口区域', '使用坐标先填回，是否应用由你决定'], anchor: 'ip' },
    search: { image: 'search.webp', alt: '输入 Seoul 后的地点自动补全建议', kicker: 'A NAME IS ENOUGH TO BEGIN.', title: ['记得名字，', '就能找到位置。'], description: '城市、地址或地标，输入后选择地点建议，地图和坐标一起更新。', points: ['自动补全使用原生 Apple MapKit', '也可以直接在地图点击落点', '「回到选点」把视野拉回当前选择'], anchor: 'select' }
  };
  const tabs = [...document.querySelectorAll('[data-feature]')];
  function selectFeature(button, focus = false) {
    const feature = features[button.dataset.feature];
    tabs.forEach(tab => { const active = tab === button; tab.setAttribute('aria-selected', String(active)); tab.tabIndex = active ? 0 : -1; });
    $('#feature-panel').setAttribute('aria-labelledby', button.id);
    const image = $('#feature-image'); image.src = `assets/${feature.image}`; image.alt = feature.alt;
    $('#feature-kicker').textContent = feature.kicker;
    const title = $('#feature-title'); title.replaceChildren(document.createTextNode(feature.title[0]), document.createElement('br'), document.createTextNode(feature.title[1]));
    $('#feature-description').textContent = feature.description;
    $('#feature-points').replaceChildren(...feature.points.map(text => { const item = document.createElement('li'); item.textContent = text; return item; }));
    $('.feature-content > .text-link').href = `guide.html#${feature.anchor}`;
    if (focus) button.focus();
  }
  tabs.forEach((button, index) => {
    button.addEventListener('click', () => selectFeature(button));
    button.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      else if (event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
      else if (event.key === 'Home') next = 0;
      else if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) { event.preventDefault(); selectFeature(tabs[next], true); }
    });
  });

  async function updateRelease() {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 6500);
    try {
      const response = await fetch('https://api.github.com/repos/Oldleeo/OldLocal/releases/latest', { headers: {Accept: 'application/vnd.github+json'}, signal: controller.signal });
      if (!response.ok) return;
      const data = await response.json();
      if (data.draft || data.prerelease || !/^v?\d+\.\d+\.\d+$/.test(data.tag_name)) return;
      const validURL = (text, prefix) => {
        try { const u = new URL(text); return u.protocol === 'https:' && u.hostname === 'github.com' && !u.username && !u.password && (!u.port || u.port === '443') && u.pathname.startsWith(prefix); } catch { return false; }
      };
      if (!validURL(data.html_url, '/Oldleeo/OldLocal/releases/tag/')) return;
      document.querySelectorAll('[data-release-label]').forEach(element => { element.textContent = `OldLocal ${data.tag_name.replace(/^v/, '')}`; });
      document.querySelectorAll('[data-release-page]').forEach(element => { element.href = data.html_url; });
      const asset = (data.assets || []).find(item => ['OldLocal-macOS-arm64.zip', 'OldLocal.zip'].includes(item.name) && validURL(item.browser_download_url, '/Oldleeo/OldLocal/releases/download/'));
      if (asset) document.querySelectorAll('[data-release-download]').forEach(element => { element.href = asset.browser_download_url; element.setAttribute('aria-label', `下载 OldLocal ${data.tag_name}，Apple Silicon 版`); });
    } catch {
      // Keep the permanent Releases link available when the API is offline or rate-limited.
    } finally { clearTimeout(timeout); }
  }
  updateRelease();
})();
