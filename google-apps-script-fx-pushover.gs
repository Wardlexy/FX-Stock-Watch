const CONFIG = {
  thresholds: {
    fxPercent: 0.50,
    stockPercent: 2.00,
  },
  sendStableNotifications: false,
  fxPairs: [
    { label: 'USD/IDR', base: 'USD', quote: 'IDR' },
    { label: 'SGD/IDR', base: 'SGD', quote: 'IDR' },
    { label: 'CNY/IDR', base: 'CNY', quote: 'IDR' },
    { label: 'EUR/IDR', base: 'EUR', quote: 'IDR' },
    { label: 'MYR/IDR', base: 'MYR', quote: 'IDR' },
    { label: 'JPY/IDR', base: 'JPY', quote: 'IDR' },
  ],
  stocks: [
    { label: 'BCA', ticker: 'BBCA.JK' },
    { label: 'Mandiri', ticker: 'BMRI.JK' },
  ],
};

function setPushoverSecrets() {
  const token = 'ISI_TOKEN_APP_PUSHOVER';
  const user = 'ISI_USER_KEY_PUSHOVER';

  if (token.startsWith('ISI_') || user.startsWith('ISI_')) {
    throw new Error('Ganti token dan user key Pushover dulu sebelum menjalankan setPushoverSecrets().');
  }

  PropertiesService.getScriptProperties().setProperties({
    PUSHOVER_APP_TOKEN: token,
    PUSHOVER_USER_KEY: user,
  });
}

function setupTriggers() {
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === 'checkMarketsAndNotify')
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));

  [8, 12, 20].forEach(hour => {
    ScriptApp.newTrigger('checkMarketsAndNotify')
      .timeBased()
      .everyDays(1)
      .atHour(hour)
      .nearMinute(0)
      .inTimezone('Asia/Jakarta')
      .create();
  });
}

function testPushoverNotification() {
  const props = PropertiesService.getScriptProperties();
  const token = props.getProperty('PUSHOVER_APP_TOKEN');
  const user = props.getProperty('PUSHOVER_USER_KEY');

  if (!token || !user) {
    throw new Error('Pushover token/user key belum tersimpan. Jalankan setPushoverSecrets() dulu.');
  }

  const timestamp = Utilities.formatDate(new Date(), 'Asia/Jakarta', 'yyyy-MM-dd HH:mm:ss');
  sendPushover_(token, user, 'FX Stock Watch test', `Test notification OK.\nTime: ${timestamp} WIB`);
}

function checkMarketsAndNotify() {
  const props = PropertiesService.getScriptProperties();
  const token = props.getProperty('PUSHOVER_APP_TOKEN');
  const user = props.getProperty('PUSHOVER_USER_KEY');

  if (!token || !user) {
    throw new Error('Isi PUSHOVER_APP_TOKEN dan PUSHOVER_USER_KEY lewat setPushoverSecrets().');
  }

  const state = readState_();
  const lines = [];
  let hasAlert = false;

  CONFIG.fxPairs.forEach(pair => {
    const key = `FX:${pair.label}`;
    const current = getFxRate_(pair.base, pair.quote);
    const move = getMoveStatus_(current, state.values[key], CONFIG.thresholds.fxPercent);

    if (move.significant || CONFIG.sendStableNotifications) {
      lines.push(`${pair.label}: ${formatIdr_(current)} - ${move.status} (${formatPct_(move.pct)})`);
    }

    hasAlert = hasAlert || move.significant;
    state.values[key] = current;
  });

  CONFIG.stocks.forEach(stock => {
    const key = `STOCK:${stock.ticker}`;
    const current = getStockPrice_(stock.ticker);
    const move = getMoveStatus_(current, state.values[key], CONFIG.thresholds.stockPercent);

    if (move.significant || CONFIG.sendStableNotifications) {
      lines.push(`${stock.label} (${stock.ticker}): ${formatIdr_(current)} - ${move.status} (${formatPct_(move.pct)})`);
    }

    hasAlert = hasAlert || move.significant;
    state.values[key] = current;
  });

  state.lastRun = new Date().toISOString();
  writeState_(state);

  if (lines.length > 0 && (hasAlert || CONFIG.sendStableNotifications)) {
    const title = hasAlert ? 'Alert kurs & saham' : 'Kurs & saham stabil';
    const timestamp = Utilities.formatDate(new Date(), 'Asia/Jakarta', 'yyyy-MM-dd HH:mm:ss');
    sendPushover_(token, user, title, `${lines.join('\n')}\nCek: ${timestamp} WIB`);
  }
}

function getFxRate_(base, quote) {
  const url = `https://open.er-api.com/v6/latest/${encodeURIComponent(base)}`;
  const data = fetchJson_(url);

  if (data.result !== 'success' || !data.rates || data.rates[quote] == null) {
    throw new Error(`Gagal ambil kurs ${base}/${quote}`);
  }

  return Number(data.rates[quote]);
}

function getStockPrice_(ticker) {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}`;
  const data = fetchJson_(url);
  const result = data.chart && data.chart.result && data.chart.result[0];
  const price = result && result.meta && result.meta.regularMarketPrice;

  if (price == null) {
    throw new Error(`Gagal ambil harga saham ${ticker}`);
  }

  return Number(price);
}

function getMoveStatus_(current, previous, thresholdPercent) {
  if (previous == null || Number(previous) === 0) {
    return { status: 'baru', pct: null, significant: true };
  }

  const pct = ((current - Number(previous)) / Number(previous)) * 100;
  let status = 'stabil';

  if (pct >= thresholdPercent) {
    status = 'naik';
  } else if (pct <= -thresholdPercent) {
    status = 'turun';
  }

  return {
    status,
    pct,
    significant: Math.abs(pct) >= thresholdPercent,
  };
}

function sendPushover_(token, user, title, message) {
  UrlFetchApp.fetch('https://api.pushover.net/1/messages.json', {
    method: 'post',
    payload: {
      token,
      user,
      title,
      message,
    },
    muteHttpExceptions: false,
  });
}

function fetchJson_(url) {
  const response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: false,
  });

  return JSON.parse(response.getContentText());
}

function readState_() {
  const raw = PropertiesService.getScriptProperties().getProperty('MARKET_WATCH_STATE');
  if (!raw) {
    return { values: {}, lastRun: null };
  }

  return JSON.parse(raw);
}

function writeState_(state) {
  PropertiesService.getScriptProperties().setProperty('MARKET_WATCH_STATE', JSON.stringify(state));
}

function formatIdr_(value) {
  return `Rp${Math.round(value).toLocaleString('id-ID')}`;
}

function formatPct_(value) {
  if (value == null) {
    return 'baseline baru';
  }

  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(2)}%`;
}
