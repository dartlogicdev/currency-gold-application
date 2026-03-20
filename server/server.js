const express = require('express');
const fetch = require('node-fetch'); // node-fetch v2
const cors = require('cors');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const app = express();
app.use(cors());

// ==================== KONFIGURATION ====================
const GOLD_API_KEY = process.env.GOLD_API_KEY;
const PORT = process.env.PORT || 3000;
const GOLD_CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24 Stunden (~60 req/Monat mit Gold+Silber)
const HISTORY_FILE = path.join(__dirname, 'gold_history.json');
const PREMIUM_PERCENT = 4;

// Dynamischer Currency Cache: 5 Min während EZB-Update (15-17 Uhr CET), sonst 2h
function getCurrencyCacheDuration() {
  const now = new Date();
  const hour = now.getUTCHours();
  const day = now.getUTCDay(); // 0=Sonntag, 6=Samstag
  
  // Wochenende: Immer langer Cache (EZB macht nichts)
  if (day === 0 || day === 6) {
    return 2 * 60 * 60 * 1000; // 2 Stunden
  }
  
  // Werktags 15-17 Uhr CET (UTC+1 Winter, UTC+2 Sommer)
  // Näherung: 14-16 UTC (passt für beide)
  if (hour >= 14 && hour < 16) {
    return 5 * 60 * 1000; // 5 Minuten
  }
  
  // Sonst: Langer Cache
  return 2 * 60 * 60 * 1000; // 2 Stunden
}

// ==================== IN-MEMORY CACHE ====================
const cache = {
  rates: { data: null, timestamp: 0 },
  gold: { data: null, timestamp: 0 }
};

function isCacheValid(cacheEntry, maxAge) {
  return cacheEntry.data && (Date.now() - cacheEntry.timestamp) < maxAge;
}

function setCache(key, data) {
  cache[key] = { data, timestamp: Date.now() };
}

// ==================== RATE LIMITING ====================
const requestCounts = new Map();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 Minute
const MAX_REQUESTS_PER_WINDOW = 30;

function rateLimitMiddleware(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress;
  const now = Date.now();
  
  if (!requestCounts.has(ip)) {
    requestCounts.set(ip, { count: 1, resetTime: now + RATE_LIMIT_WINDOW });
  } else {
    const record = requestCounts.get(ip);
    if (now > record.resetTime) {
      record.count = 1;
      record.resetTime = now + RATE_LIMIT_WINDOW;
    } else {
      record.count++;
      if (record.count > MAX_REQUESTS_PER_WINDOW) {
        return res.status(429).json({ 
          error: 'Too many requests', 
          retryAfter: Math.ceil((record.resetTime - now) / 1000) 
        });
      }
    }
  }
  next();
}

app.use(rateLimitMiddleware);

// ==================== HISTORY MANAGEMENT ====================
function loadHistory() {
  if (!fs.existsSync(HISTORY_FILE)) return [];
  try {
    return JSON.parse(fs.readFileSync(HISTORY_FILE));
  } catch (err) {
    console.error('History Load Fehler:', err);
    return [];
  }
}

function saveHistory(data) {
  try {
    fs.writeFileSync(HISTORY_FILE, JSON.stringify(data, null, 2));
  } catch (err) {
    console.error('History Save Fehler:', err);
  }
}

async function storeTodayGoldPrice(pricePerGramUSD) {
  const history = loadHistory();
  const today = new Date().toISOString().split('T')[0];

  const exists = history.find(h => h.date === today);
  if (exists) return;

  history.push({
    date: today,
    priceUSD: Number(pricePerGramUSD.toFixed(2)),
  });

  saveHistory(history);
  console.log('Goldpreis gespeichert:', today);
}

// ==================== ENDPOINTS ====================

// Health Check für Deployment
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Chart - Historische Daten
app.get('/gold/history', (req, res) => {
  const days = Number(req.query.days ?? 30);
  const history = loadHistory();

  const sliced = history.slice(-days);
  res.json(sliced);
});

// WÄHRUNGEN mit Caching
app.get('/rates', async (req, res) => {
  const cacheDuration = getCurrencyCacheDuration();
  console.log(`Currency Cache-Dauer: ${cacheDuration / 60000} Minuten`);
  
  // Prüfe Cache zuerst
  if (isCacheValid(cache.rates, cacheDuration)) {
    console.log('Serving rates from cache');
    const response = {
      ...cache.rates.data,
      cached: true,
      cacheAge: Math.floor((Date.now() - cache.rates.timestamp) / 1000),
      nextUpdate: Math.floor((cache.rates.timestamp + cacheDuration - Date.now()) / 1000)
    };
    return res.json(response);
  }

  try {
    console.log('Fetching fresh rates data...');
    const response = await fetch('https://api.frankfurter.app/latest');
    const data = await response.json();
    
    setCache('rates', data);
    
    const enhancedData = {
      ...data,
      cached: false,
      fetchedAt: new Date().toISOString()
    };
    
    res.json(enhancedData);
  } catch (err) {
    console.error('Currency Fetch Fehler:', err);
    
    // Fallback auf alten Cache oder Standardwerte
    if (cache.rates.data) {
      console.log('Using stale cache as fallback');
      return res.json({
        ...cache.rates.data,
        cached: true,
        stale: true
      });
    }
    
    res.json({
      base: 'EUR',
      rates: { USD: 1.1, GBP: 0.85, TRY: 32.0, EUR: 1.0 },
      fallback: true
    });
  }
});

// GOLD Preise mit Caching
app.get('/gold', async (req, res) => {
  console.log('Gold Request empfangen...');

  // Münzen-Definitionen
  const coins = {
    'Gold (1g)': { weight: 1, karat: 24 },
    'Gold (1kg)': { weight: 1000, karat: 24 },
    'Unze (1 oz)': { weight: 31.1035, karat: 24 },
    'Cumhuriyet Altını': { weight: 7.21, karat: 22 },
    'Ata Altını': { weight: 7.21, karat: 22 },
    'Çeyrek Altın': { weight: 1.75, karat: 22 },
    'Yarim Altın': { weight: 3.5, karat: 22 },
    'Tam Altın (Ziynet)': { weight: 7.01, karat: 22 },
    'Reşat Altını': { weight: 7.21, karat: 22 },
    'Gremse Altını': { weight: 17.5, karat: 22 },
    '22 Ayar Bilezik': { weight: 1, karat: 22 },
  };

  // Prüfe Cache zuerst
  if (isCacheValid(cache.gold, GOLD_CACHE_DURATION_MS)) {
    console.log('Serving gold data from cache');
    return res.json(cache.gold.data);
  }

  try {
    if (!GOLD_API_KEY) {
      throw new Error('Kein GoldAPI-Key gesetzt. Bitte GOLD_API_KEY in .env setzen.');
    }

    console.log('Fetching fresh gold data...');
    
    // Gold- und Silberpreis parallel abrufen
    const [goldResponse, silverResponse] = await Promise.all([
      fetch('https://www.goldapi.io/api/XAU/USD', { headers: { 'x-access-token': GOLD_API_KEY } }),
      fetch('https://www.goldapi.io/api/XAG/USD', { headers: { 'x-access-token': GOLD_API_KEY } }),
    ]);
    
    if (!goldResponse.ok) {
      throw new Error(`GoldAPI Error: ${goldResponse.status} ${goldResponse.statusText}`);
    }
    
    const goldData = await goldResponse.json();
    console.log('GoldAPI Response (Gold):', goldData);

    if (!goldData.price) throw new Error('Kein Preis von GoldAPI');

    const pricePerOzUSD = goldData.price;
    const pricePerGramUSD = pricePerOzUSD / 31.1035;
    await storeTodayGoldPrice(pricePerGramUSD);

    // Silberpreis
    let silverPricePerGramUSD = 0;
    if (silverResponse.ok) {
      const silverData = await silverResponse.json();
      console.log('GoldAPI Response (Silber):', silverData);
      if (silverData.price) silverPricePerGramUSD = silverData.price / 31.1035;
    }

    // Wechselkurse USD -> weitere Währungen
    const rateResponse = await fetch(
      'https://api.frankfurter.app/latest?from=USD&to=EUR,TRY,GBP,CHF,JPY,AUD,CAD,INR'
    );
    const rateData = await rateResponse.json();

    const rates = {
      USD: 1,
      EUR: rateData.rates.EUR || 0.93,
      TRY: rateData.rates.TRY || 34.0,
      GBP: rateData.rates.GBP || 0.79,
      CHF: rateData.rates.CHF || 0.90,
      JPY: rateData.rates.JPY || 149.0,
      AUD: rateData.rates.AUD || 1.53,
      CAD: rateData.rates.CAD || 1.36,
      INR: rateData.rates.INR || 83.0,
      SAR: 3.75,  // Fest an USD gekoppelt
      AED: 3.67,  // Fest an USD gekoppelt
    };

    // Berechnung pro Goldmünze
    const result = {};
    for (const [coin, data] of Object.entries(coins)) {
      const purity = data.karat / 24;
      const spotUSD = data.weight * purity * pricePerGramUSD;

      const coinEntry = { weight: data.weight, karat: data.karat };

      for (const [cur, rate] of Object.entries(rates)) {
        const spot = spotUSD * rate;
        const dealer = spot * (1 + PREMIUM_PERCENT / 100);
        coinEntry[cur] = {
          spot: parseFloat(spot.toFixed(2)),
          dealer: parseFloat(dealer.toFixed(2)),
        };
      }

      result[coin] = coinEntry;
    }

    // Silber-Einträge
    if (silverPricePerGramUSD > 0) {
      const silverItems = {
        'Silber (1g)': { weight: 1, karat: 24 },
        'Silber (1kg)': { weight: 1000, karat: 24 },
      };
      for (const [name, data] of Object.entries(silverItems)) {
        const silverEntry = { weight: data.weight, karat: data.karat, metal: 'silver' };
        for (const [cur, rate] of Object.entries(rates)) {
          const spot = data.weight * silverPricePerGramUSD * rate;
          const dealer = spot * (1 + PREMIUM_PERCENT / 100);
          silverEntry[cur] = {
            spot: parseFloat(spot.toFixed(2)),
            dealer: parseFloat(dealer.toFixed(2)),
          };
        }
        result[name] = silverEntry;
      }
    }

    const responseData = { 
      coins: result,
      cached: false,
      timestamp: new Date().toISOString()
    };
    
    setCache('gold', responseData);
    res.json(responseData);
    
  } catch (err) {
    console.error('Gold Fetch Fehler:', err.message);

    // Fallback auf alten Cache
    if (cache.gold.data) {
      console.log('Using stale gold cache as fallback');
      const staleData = { ...cache.gold.data, stale: true };
      return res.json(staleData);
    }

    // Fallback-Testwerte als letzte Option
    console.log('Using fallback test values');
    const testRates = { USD: 1, EUR: 0.93, TRY: 34, GBP: 0.79, CHF: 0.90, JPY: 149, AUD: 1.53, CAD: 1.36, INR: 83, SAR: 3.75, AED: 3.67 };
    const testPricePerGramUSD = 90; // ~2800 USD/oz ≈ 90 USD/g (aktualisiert Feb 2026)

    const fallbackResult = {};
    for (const [coin, data] of Object.entries(coins)) {
      const purity = data.karat / 24;
      const spotUSD = data.weight * purity * testPricePerGramUSD;

      const coinEntry = { weight: data.weight, karat: data.karat };
      for (const [cur, rate] of Object.entries(testRates)) {
        const spot = spotUSD * rate;
        const dealer = spot * 1.04;
        coinEntry[cur] = {
          spot: parseFloat(spot.toFixed(2)),
          dealer: parseFloat(dealer.toFixed(2)),
        };
      }

      fallbackResult[coin] = coinEntry;
    }

    res.json({ 
      coins: fallbackResult,
      fallback: true,
      timestamp: new Date().toISOString()
    });
  }
});

// ==================== SERVER START ====================
app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════╗
║   Currency & Gold Server                      ║
║   Running on: http://localhost:${PORT}        ║
║   Cache: Currency (dynamisch 5min-2h), Gold ${GOLD_CACHE_DURATION_MS/1000}s  ║
║   Rate Limit: ${MAX_REQUESTS_PER_WINDOW} req/min              ║
╚═══════════════════════════════════════════════╝
  `);
});
