type Bucket = {
  count: number;
  resetAt: number;
};

type RateLimitResult = {
  allowed: boolean;
  retryAfterSeconds: number;
};

type RateLimitStore = typeof globalThis & {
  __vectorWebsiteRateLimitStore?: Map<string, Bucket>;
};

const store = globalThis as RateLimitStore;

export function clientRateLimitKey(request: Request, namespace: string) {
  const forwardedFor = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const userAgent = request.headers.get("user-agent") ?? "unknown";
  return `${namespace}:${forwardedFor}:${userAgent}`;
}

export function checkRateLimit(key: string, limit: number, windowMs: number): RateLimitResult {
  const buckets = store.__vectorWebsiteRateLimitStore ?? new Map<string, Bucket>();
  store.__vectorWebsiteRateLimitStore = buckets;

  const now = Date.now();
  if (buckets.size > 10_000) {
    for (const [bucketKey, bucket] of buckets.entries()) {
      if (bucket.resetAt <= now) {
        buckets.delete(bucketKey);
      }
    }
  }

  const current = buckets.get(key);
  if (!current || current.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return { allowed: true, retryAfterSeconds: 0 };
  }

  if (current.count >= limit) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil((current.resetAt - now) / 1000)),
    };
  }

  current.count += 1;
  buckets.set(key, current);
  return { allowed: true, retryAfterSeconds: 0 };
}

export function noStoreHeaders(extra?: HeadersInit): HeadersInit {
  return {
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    ...extra,
  };
}
