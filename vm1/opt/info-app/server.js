const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 4000;
const SERVICE_NAME = 'sysinfo-service';
const ENV = process.env.NODE_ENV || 'development';

// Core Logger function chuẩn JSON format
function logger(level, message, meta = {}) {
  const logPayload = {
    timestamp: new Date().toISOString(),
    level: level.toUpperCase(),
    service: SERVICE_NAME,
    environment: ENV,
    pid: process.pid,
    message,
    ...meta,
  };

  const output = JSON.stringify(logPayload);

  // stdout cho INFO/DEBUG, stderr cho WARN/ERROR
  if (level === 'error' || level === 'warn') {
    process.stderr.write(output + '\n');
  } else {
    process.stdout.write(output + '\n');
  }
}

// Helper đổi bytes -> GB
function formatBytes(bytes) {
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// Helper format thời gian chạy
function formatUptime(seconds) {
  const d = Math.floor(seconds / (3600 * 24));
  const h = Math.floor((seconds % (3600 * 24)) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  return `${d}d ${h}h ${m}m ${s}s`;
}

// Handler request chính
const server = http.createServer((req, res) => {
  const startTime = process.hrtime();

  // Lấy IP client (hỗ trợ cả khi chạy sau Reverse Proxy như Nginx/HAProxy)
  const clientIp = req.headers['x-forwarded-for']?.split(',')[0] || req.socket.remoteAddress;

  // Lắng nghe sự kiện finish để ghi HTTP Access Log
  res.on('finish', () => {
    const diff = process.hrtime(startTime);
    const durationMs = (diff[0] * 1e3 + diff[1] * 1e-6).toFixed(2); // ms

    const logMeta = {
      http: {
        method: req.method,
        url: req.url,
        status_code: res.statusCode,
        client_ip: clientIp,
        user_agent: req.headers['user-agent'] || 'unknown',
        latency_ms: parseFloat(durationMs),
      },
    };

    if (res.statusCode >= 500) {
      logger('error', 'HTTP Request failed with server error', logMeta);
    } else if (res.statusCode >= 400) {
      logger('warn', 'HTTP Request returned client error', logMeta);
    } else {
      logger('info', 'HTTP Request completed', logMeta);
    }
  });

  // Routing
  if (req.method === 'GET' && (req.url === '/' || req.url === '/metrics')) {
    try {
      const totalMem = os.totalmem();
      const freeMem = os.freemem();
      const usedMem = totalMem - freeMem;

      const sysInfo = {
        status: 'success',
        timestamp: new Date().toISOString(),
        system: {
          hostname: os.hostname(),
          platform: os.platform(),
          architecture: os.arch(),
          release: os.release(),
          uptime: formatUptime(os.uptime()),
        },
        cpu: {
          model: os.cpus()[0]?.model || 'Unknown',
          cores: os.cpus().length,
          loadAverage: os.loadavg(),
        },
        memory: {
          total: formatBytes(totalMem),
          used: formatBytes(usedMem),
          free: formatBytes(freeMem),
          usagePercentage: ((usedMem / totalMem) * 100).toFixed(2) + '%',
        },
        process: {
          pid: process.pid,
          nodeVersion: process.version,
          uptime: formatUptime(process.uptime()),
          memoryUsage: {
            rss: formatBytes(process.memoryUsage().rss),
            heapTotal: formatBytes(process.memoryUsage().heapTotal),
            heapUsed: formatBytes(process.memoryUsage().heapUsed),
          },
        },
        network: os.networkInterfaces(),
      };

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(sysInfo, null, 2));
    } catch (err) {
      logger('error', 'Unhandled error while processing system metrics', {
        error: { message: err.message, stack: err.stack },
      });
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Internal Server Error' }));
    }
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Route Not Found' }));
  }
});

// Start Server
server.listen(PORT, '127.0.0.1', () => {
  logger('info', `Server successfully started on port ${PORT}`, {
    config: { port: PORT, env: ENV, node_version: process.version },
  });
});

// --- Graceful Shutdown & Uncaught Error Handling ---

function shutdown(signal) {
  logger('warn', `Received ${signal}. Initiating graceful shutdown...`);

  server.close(() => {
    logger('info', 'HTTP server closed. Exiting process.');
    process.exit(0);
  });

  // Force exit nếu shutdown quá 10 giây (dùng cho K8s terminationGracePeriodSeconds)
  setTimeout(() => {
    logger('error', 'Forced shutdown executed due to timeout.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('uncaughtException', (err) => {
  logger('error', 'Uncaught Exception detected!', {
    error: { message: err.message, stack: err.stack },
  });
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger('error', 'Unhandled Promise Rejection detected!', {
    reason: reason instanceof Error ? { message: reason.message, stack: reason.stack } : reason,
  });
});
